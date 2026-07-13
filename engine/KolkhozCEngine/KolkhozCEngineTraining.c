#include "KolkhozCEngineInternal.h"

#include <math.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

static int32_t kc_rank_for_player(const int32_t *scores, const int32_t *medals, int32_t player_id) {
    int32_t rank = 1;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other != player_id && kc_player_beats_player(scores, medals, other, player_id)) {
            rank++;
        }
    }
    return rank;
}

static double kc_raw_reward_for_player(const int32_t *scores, const int32_t *medals, int32_t winner_id, int32_t player_id, KCPolicyGradientConfig config) {
    int32_t best_opponent = -1;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == player_id) {
            continue;
        }
        if (best_opponent < 0 || kc_player_beats_player(scores, medals, other, best_opponent)) {
            best_opponent = other;
        }
    }
    double is_top = winner_id == player_id ? 1.0 : 0.0;
    double is_strict_top = best_opponent >= 0 && kc_player_beats_player(scores, medals, player_id, best_opponent) ? 1.0 : 0.0;
    double rank_penalty = (double)(kc_rank_for_player(scores, medals, player_id) - 1);
    double margin = best_opponent >= 0 ? (double)(scores[player_id] - scores[best_opponent]) : 0.0;
    return config.win_weight * is_top + config.strict_weight * is_strict_top - config.rank_weight * rank_penalty + config.margin_weight * margin;
}

static bool kc_has_shaped_rewards(KCPolicyGradientConfig config) {
    return config.score_delta_weight != 0 ||
        config.margin_delta_weight != 0 ||
        config.work_delta_weight != 0 ||
        config.claim_delta_weight != 0 ||
        config.own_requisition_weight != 0;
}

static int32_t kc_score_margin_for_player(const KCEngine *engine, int32_t player_id) {
    int32_t own_score = kc_final_score(engine, player_id);
    int32_t best_opponent = -1000000;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == player_id) continue;
        int32_t opponent_score = kc_final_score(engine, other);
        if (opponent_score > best_opponent) best_opponent = opponent_score;
    }
    return own_score - best_opponent;
}

static int32_t kc_total_work_hours(const KCEngine *engine) {
    int32_t total = 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        total += engine->work_hours[suit];
    }
    return total;
}

static int32_t kc_claimed_job_count(const KCEngine *engine) {
    int32_t count = 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        count += engine->claimed_jobs[suit] ? 1 : 0;
    }
    return count;
}

static int32_t kc_own_requisition_count(const KCEngine *engine, int32_t player_id) {
    int32_t count = 0;
    for (int32_t index = 0; index < engine->requisition_event_count; index++) {
        KCRequisitionEvent event = engine->requisition_events[index];
        if (event.player_id == player_id && kc_card_valid(event.card)) {
            count++;
        }
    }
    return count;
}

static double kc_shaped_reward_delta(
    const KCEngine *engine,
    int32_t player_id,
    int32_t before_score,
    int32_t before_margin,
    int32_t before_work,
    int32_t before_claims,
    int32_t before_requisitions,
    KCPolicyGradientConfig config
) {
    double score_delta = (double)(kc_final_score(engine, player_id) - before_score);
    double margin_delta = (double)(kc_score_margin_for_player(engine, player_id) - before_margin);
    double work_delta = (double)(kc_total_work_hours(engine) - before_work);
    double claim_delta = (double)(kc_claimed_job_count(engine) - before_claims);
    double requisition_delta = (double)(kc_own_requisition_count(engine, player_id) - before_requisitions);
    return config.score_delta_weight * score_delta
        + config.margin_delta_weight * margin_delta
        + config.work_delta_weight * work_delta
        + config.claim_delta_weight * claim_delta
        - config.own_requisition_weight * requisition_delta;
}

static void kc_value_add_one_hot(double *features, int32_t base, int32_t selected, int32_t count) {
    if (selected >= 0 && selected < count) {
        features[base + selected] = 1.0;
    }
}

static void kc_value_features(const KCEngine *engine, int32_t player_id, int32_t action_head, double *features) {
    memset(features, 0, KC_VALUE_INPUT_SIZE * sizeof(double));
    const KCPlayer *player = &engine->players[player_id];
    int32_t lead_suit = kc_lead_suit(engine);
    int32_t own_score = kc_known_score_for_player(engine, player_id);
    int32_t best_opponent = -1000000;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == player_id) continue;
        int32_t score = kc_visible_score(engine, other);
        if (score > best_opponent) best_opponent = score;
    }

    kc_value_add_one_hot(features, 0, action_head, KC_SUIT_COUNT);
    kc_value_add_one_hot(features, 4, player_id, KC_PLAYER_COUNT);
    features[8] = (double)engine->year / 5.0;
    features[9] = (double)engine->trick_count / 4.0;
    features[10] = engine->is_famine ? 1.0 : 0.0;
    features[11] = (double)player->hand.count / 5.0;
    features[12] = player->has_won_trick_this_year ? 1.0 : 0.0;
    features[13] = (double)kc_total_medals_for_player(engine, player_id) / 20.0;
    features[14] = (double)own_score / 100.0;
    features[15] = (double)best_opponent / 100.0;
    features[16] = (double)(own_score - best_opponent) / 100.0;
    features[17] = (double)engine->current_trick_count / 4.0;

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        features[18 + suit] = (double)engine->work_hours[suit] / 40.0;
        features[22 + suit] = engine->claimed_jobs[suit] ? 1.0 : 0.0;
        features[26 + suit] = engine->has_revealed_job[suit] ? (double)engine->revealed_jobs[suit].value / 5.0 : 0.0;
    }
    for (int32_t card_index = 0; card_index < player->hand.count; card_index++) {
        KCCard card = player->hand.cards[card_index];
        for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
            if (kc_card_matches_suit(card, suit)) features[30 + suit] += 1.0 / 5.0;
        }
    }
    for (int32_t card_index = 0; card_index < player->plot_hidden.count; card_index++) {
        KCCard card = player->plot_hidden.cards[card_index];
        for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
            if (kc_card_matches_suit(card, suit)) features[34 + suit] += 1.0 / 8.0;
        }
    }
    for (int32_t card_index = 0; card_index < player->plot_revealed.count; card_index++) {
        KCCard card = player->plot_revealed.cards[card_index];
        for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
            if (kc_card_matches_suit(card, suit)) features[38 + suit] += 1.0 / 8.0;
        }
    }
    kc_value_add_one_hot(features, 42, engine->trump, KC_SUIT_COUNT);
    kc_value_add_one_hot(features, 46, lead_suit, KC_SUIT_COUNT);
    features[50] = 1.0;
}

static double kc_value_prediction(const double *weights, const double *features) {
    double value = 0;
    for (int32_t index = 0; index < KC_VALUE_INPUT_SIZE; index++) {
        value += weights[index] * features[index];
    }
    return value;
}

static void kc_add_value_gradient(double *gradient, const double *features, double error) {
    for (int32_t index = 0; index < KC_VALUE_INPUT_SIZE; index++) {
        gradient[index] += error * features[index];
    }
}

static double kc_clip_advantage(double advantage, double limit) {
    if (limit <= 0) {
        return advantage;
    }
    if (advantage > limit) {
        return limit;
    }
    if (advantage < -limit) {
        return -limit;
    }
    return advantage;
}

static double kc_value_baseline_for_head(
    int32_t player_id,
    int32_t action_head,
    int32_t value_count,
    double target,
    double *value_gradient,
    double *episode_value_features,
    double *episode_value_predictions
) {
    double learned_baseline = 0;
    int32_t matched = 0;
    for (int32_t value_index = 0; value_index < value_count; value_index++) {
        double *features = episode_value_features + (((size_t)player_id * KC_MAX_POLICY_DECISIONS + value_index) * KC_VALUE_INPUT_SIZE);
        if (features[action_head] < 0.5) {
            continue;
        }
        double prediction = episode_value_predictions[(size_t)player_id * KC_MAX_POLICY_DECISIONS + value_index];
        learned_baseline += prediction;
        kc_add_value_gradient(value_gradient, features, target - prediction);
        matched++;
    }
    return matched > 0 ? learned_baseline / (double)matched : 0;
}

static void kc_add_scaled(double *destination, const double *source, int32_t count, double scale) {
    for (int32_t i = 0; i < count; i++) {
        destination[i] += source[i] * scale;
    }
}

static double kc_gradient_norm(const double *gradient, int32_t count) {
    double total = 0;
    for (int32_t i = 0; i < count; i++) {
        total += gradient[i] * gradient[i];
    }
    return sqrt(total);
}

static double kc_policy_weight_checksum(KCPolicyModelBuffer model, const double *value_weights) {
    double checksum = 0;
    int32_t ordinal = 1;
    int32_t layer_count = kc_policy_layer_count(model);
    for (int32_t layer = 0; layer < layer_count; layer++) {
        int32_t input_size = kc_policy_layer_input_size(model, layer);
        int32_t output_size = kc_policy_layer_size(model, layer);
        int32_t weight_count = input_size * output_size;
        double *weights = kc_policy_layer_weights(model, layer);
        double *biases = kc_policy_layer_biases(model, layer);
        for (int32_t i = 0; i < weight_count; i++) {
            checksum += weights[i] * (double)ordinal++;
        }
        for (int32_t i = 0; i < output_size; i++) {
            checksum += biases[i] * (double)ordinal++;
        }
    }
    int32_t head_count = model.head_count > 1 ? model.head_count : 1;
    int32_t last_size = kc_policy_layer_size(model, layer_count - 1);
    double *output_weights = kc_policy_output_weights(model);
    for (int32_t i = 0; i < last_size * head_count; i++) {
        checksum += output_weights[i] * (double)ordinal++;
    }
    for (int32_t i = 0; i < head_count; i++) {
        if (model.b2s) {
            checksum += model.b2s[i] * (double)ordinal++;
        }
    }
    if (value_weights) {
        for (int32_t i = 0; i < KC_VALUE_INPUT_SIZE; i++) {
            checksum += value_weights[i] * (double)ordinal++;
        }
    }
    return checksum;
}

static void kc_apply_gradient_to_model(KCPolicyModelBuffer model, double *gradient, KCPolicyGradientConfig config, int32_t divisor, double *norm_out, double *scale_out) {
    int32_t param_count = kc_policy_parameter_count(model);
    double safe_divisor = (double)(divisor > 0 ? divisor : 1);
    double norm = kc_gradient_norm(gradient, param_count) / safe_divisor;
    double clip_scale = norm > config.max_gradient_norm ? config.max_gradient_norm / norm : 1.0;
    double step = config.learning_rate * clip_scale / safe_divisor;
    int32_t head_count = model.head_count > 1 ? model.head_count : 1;
    int32_t layer_count = kc_policy_layer_count(model);
    int32_t offset = 0;
    if (!config.freeze_hidden) {
        for (int32_t layer = 0; layer < layer_count; layer++) {
            int32_t input_size = kc_policy_layer_input_size(model, layer);
            int32_t output_size = kc_policy_layer_size(model, layer);
            int32_t weight_count = input_size * output_size;
            double *weights = kc_policy_layer_weights(model, layer);
            double *biases = kc_policy_layer_biases(model, layer);
            for (int32_t i = 0; i < weight_count; i++) {
                weights[i] += step * gradient[offset + i] - config.learning_rate * config.l2 * weights[i];
            }
            offset += weight_count;
            for (int32_t i = 0; i < output_size; i++) {
                biases[i] += step * gradient[offset + i] - config.learning_rate * config.l2 * biases[i];
            }
            offset += output_size;
        }
    } else {
        offset = kc_policy_output_offset(model);
    }
    int32_t last_size = kc_policy_layer_size(model, layer_count - 1);
    double *output_weights = kc_policy_output_weights(model);
    for (int32_t i = 0; i < last_size * head_count; i++) {
        output_weights[i] += step * gradient[offset + i] - config.learning_rate * config.l2 * output_weights[i];
    }
    offset += last_size * head_count;
    for (int32_t i = 0; i < head_count; i++) {
        if (model.b2s) {
            model.b2s[i] += step * gradient[offset + i] - config.learning_rate * config.l2 * model.b2s[i];
        }
    }
    *model.b2 = model.b2s ? model.b2s[0] : (*model.b2 + step * gradient[offset] - config.learning_rate * config.l2 * *model.b2);
    *norm_out = norm;
    *scale_out = clip_scale;
}

static void kc_adam_update_param(double *param, double *gradient, double *m, double *v, int32_t offset, double scale, double l2, double beta1, double beta2, double bias1, double bias2, double epsilon, double learning_rate) {
    double g = scale * gradient[offset] - l2 * (*param);
    m[offset] = beta1 * m[offset] + (1.0 - beta1) * g;
    v[offset] = beta2 * v[offset] + (1.0 - beta2) * g * g;
    double m_hat = m[offset] / bias1;
    double v_hat = v[offset] / bias2;
    *param += learning_rate * m_hat / (sqrt(v_hat) + epsilon);
}

static void kc_apply_adam_gradient_to_model(
    KCPolicyModelBuffer model,
    double *gradient,
    KCPolicyGradientConfig config,
    int32_t divisor,
    double *m,
    double *v,
    int32_t timestep,
    double *norm_out,
    double *scale_out
) {
    int32_t param_count = kc_policy_parameter_count(model);
    double safe_divisor = (double)(divisor > 0 ? divisor : 1);
    double norm = kc_gradient_norm(gradient, param_count) / safe_divisor;
    double clip_scale = norm > config.max_gradient_norm ? config.max_gradient_norm / norm : 1.0;
    double gradient_scale = clip_scale / safe_divisor;
    double beta1 = config.adam_beta1 > 0 && config.adam_beta1 < 1 ? config.adam_beta1 : 0.9;
    double beta2 = config.adam_beta2 > 0 && config.adam_beta2 < 1 ? config.adam_beta2 : 0.999;
    double epsilon = config.adam_epsilon > 0 ? config.adam_epsilon : 1e-8;
    double bias1 = 1.0 - pow(beta1, (double)timestep);
    double bias2 = 1.0 - pow(beta2, (double)timestep);
    if (bias1 <= 0) bias1 = 1.0;
    if (bias2 <= 0) bias2 = 1.0;

    int32_t head_count = model.head_count > 1 ? model.head_count : 1;
    int32_t layer_count = kc_policy_layer_count(model);
    int32_t offset = 0;
    if (!config.freeze_hidden) {
        for (int32_t layer = 0; layer < layer_count; layer++) {
            int32_t input_size = kc_policy_layer_input_size(model, layer);
            int32_t output_size = kc_policy_layer_size(model, layer);
            int32_t weight_count = input_size * output_size;
            double *weights = kc_policy_layer_weights(model, layer);
            double *biases = kc_policy_layer_biases(model, layer);
            for (int32_t i = 0; i < weight_count; i++) {
                kc_adam_update_param(&weights[i], gradient, m, v, offset + i, gradient_scale, config.l2, beta1, beta2, bias1, bias2, epsilon, config.learning_rate);
            }
            offset += weight_count;
            for (int32_t i = 0; i < output_size; i++) {
                kc_adam_update_param(&biases[i], gradient, m, v, offset + i, gradient_scale, config.l2, beta1, beta2, bias1, bias2, epsilon, config.learning_rate);
            }
            offset += output_size;
        }
    } else {
        offset = kc_policy_output_offset(model);
    }
    int32_t last_size = kc_policy_layer_size(model, layer_count - 1);
    double *output_weights = kc_policy_output_weights(model);
    for (int32_t i = 0; i < last_size * head_count; i++) {
        kc_adam_update_param(&output_weights[i], gradient, m, v, offset + i, gradient_scale, config.l2, beta1, beta2, bias1, bias2, epsilon, config.learning_rate);
    }
    offset += last_size * head_count;
    for (int32_t i = 0; i < head_count; i++) {
        if (model.b2s) {
            kc_adam_update_param(&model.b2s[i], gradient, m, v, offset + i, gradient_scale, config.l2, beta1, beta2, bias1, bias2, epsilon, config.learning_rate);
        }
    }
    if (model.b2s) {
        *model.b2 = model.b2s[0];
    } else {
        kc_adam_update_param(model.b2, gradient, m, v, offset, gradient_scale, config.l2, beta1, beta2, bias1, bias2, epsilon, config.learning_rate);
    }
    *norm_out = norm;
    *scale_out = clip_scale;
}

typedef struct {
    int32_t actions;
    int32_t checksum;
    double top_rate;
    double average_rank;
    double average_margin;
    double average_reward;
    double average_advantage;
} KCEpisodePolicyResult;

typedef struct {
    int32_t candidate_offset;
    int32_t candidate_count;
    int32_t chosen_index;
    int32_t teacher_index;
    int32_t player_id;
    int32_t action_head;
    double old_log_probability;
    double advantage;
    double update_weight;
    double value_prediction;
    double shaped_reward;
    double value_features[KC_VALUE_INPUT_SIZE];
} KCPPORolloutTransition;

typedef struct {
    KCPPORolloutTransition *transitions;
    int32_t transition_count;
    int32_t transition_capacity;
    KCPolicyActionCandidate *candidates;
    int32_t candidate_count;
    int32_t candidate_capacity;
} KCPPORollout;

typedef struct {
    double kl;
    double abs_kl;
    double entropy;
    int32_t clip_count;
    int32_t transition_count;
} KCPPOMetrics;

static void kc_ppo_rollout_init(KCPPORollout *rollout) {
    memset(rollout, 0, sizeof(*rollout));
}

static void kc_ppo_rollout_clear(KCPPORollout *rollout) {
    rollout->transition_count = 0;
    rollout->candidate_count = 0;
}

static void kc_ppo_rollout_free(KCPPORollout *rollout) {
    free(rollout->transitions);
    free(rollout->candidates);
    memset(rollout, 0, sizeof(*rollout));
}

static void kc_shuffle_transition_indices(uint64_t *rng_state, int32_t *indices, int32_t count) {
    for (int32_t index = 0; index < count; index++) {
        indices[index] = index;
    }
    for (int32_t index = 0; index + 1 < count; index++) {
        int32_t remaining = count - index;
        int32_t swap_offset = (int32_t)(kc_uniform_from_state(rng_state) * (double)remaining);
        if (swap_offset < 0) swap_offset = 0;
        if (swap_offset >= remaining) swap_offset = remaining - 1;
        int32_t swap_index = index + swap_offset;
        int32_t tmp = indices[index];
        indices[index] = indices[swap_index];
        indices[swap_index] = tmp;
    }
}

static bool kc_ppo_rollout_reserve(KCPPORollout *rollout, int32_t added_transitions, int32_t added_candidates) {
    int32_t required_transitions = rollout->transition_count + added_transitions;
    if (required_transitions > rollout->transition_capacity) {
        int32_t new_capacity = rollout->transition_capacity > 0 ? rollout->transition_capacity * 2 : 512;
        while (new_capacity < required_transitions) {
            new_capacity *= 2;
        }
        KCPPORolloutTransition *new_transitions = realloc(rollout->transitions, (size_t)new_capacity * sizeof(KCPPORolloutTransition));
        if (!new_transitions) {
            return false;
        }
        rollout->transitions = new_transitions;
        rollout->transition_capacity = new_capacity;
    }

    int32_t required_candidates = rollout->candidate_count + added_candidates;
    if (required_candidates > rollout->candidate_capacity) {
        int32_t new_capacity = rollout->candidate_capacity > 0 ? rollout->candidate_capacity * 2 : 8192;
        while (new_capacity < required_candidates) {
            new_capacity *= 2;
        }
        KCPolicyActionCandidate *new_candidates = realloc(rollout->candidates, (size_t)new_capacity * sizeof(KCPolicyActionCandidate));
        if (!new_candidates) {
            return false;
        }
        rollout->candidates = new_candidates;
        rollout->candidate_capacity = new_capacity;
    }
    return true;
}

static bool kc_ppo_rollout_append(
    KCPPORollout *rollout,
    const KCPolicyActionCandidate *candidates,
    int32_t candidate_count,
    int32_t chosen_index,
    double old_log_probability,
    int32_t player_id,
    int32_t action_head,
    const double *value_features,
    double value_prediction,
    int32_t teacher_index
) {
    if (candidate_count <= 0 || chosen_index < 0 || chosen_index >= candidate_count) {
        return false;
    }
    if (!kc_ppo_rollout_reserve(rollout, 1, candidate_count)) {
        return false;
    }
    int32_t candidate_offset = rollout->candidate_count;
    for (int32_t index = 0; index < candidate_count; index++) {
        rollout->candidates[candidate_offset + index] = candidates[index];
        rollout->candidates[candidate_offset + index].hidden = NULL;
    }
    KCPPORolloutTransition *transition = &rollout->transitions[rollout->transition_count++];
    memset(transition, 0, sizeof(*transition));
    transition->candidate_offset = candidate_offset;
    transition->candidate_count = candidate_count;
    transition->chosen_index = chosen_index;
    transition->teacher_index = teacher_index;
    transition->player_id = player_id;
    transition->action_head = action_head;
    transition->old_log_probability = old_log_probability;
    transition->update_weight = 1.0;
    transition->value_prediction = value_prediction;
    if (value_features) {
        memcpy(transition->value_features, value_features, KC_VALUE_INPUT_SIZE * sizeof(double));
    }
    rollout->candidate_count += candidate_count;
    return true;
}

static void kc_add_ppo_transition_gradient(
    KCPolicyModelBuffer model,
    KCPolicyGradientConfig config,
    KCPPORollout *rollout,
    const KCPPORolloutTransition *transition,
    double *hidden_cache,
    double *gradient,
    KCPPOMetrics *metrics
) {
    int32_t count = transition->candidate_count;
    if (count <= 0 || count > 256 || transition->chosen_index < 0 || transition->chosen_index >= count) {
        return;
    }
    double safe_temperature = config.temperature > 0.05 ? config.temperature : 0.05;
    int32_t activation_count = kc_policy_activation_count(model);
    KCPolicyActionCandidate *candidates = rollout->candidates + transition->candidate_offset;
    double logits[256];
    double max_logit = 0;
    for (int32_t index = 0; index < count; index++) {
        candidates[index].hidden = hidden_cache + ((size_t)index * (size_t)activation_count);
        candidates[index].score = candidates[index].has_features
            ? kc_model_score_cached(model, &candidates[index], candidates[index].hidden)
            : 0;
        logits[index] = candidates[index].score / safe_temperature;
        if (index == 0 || logits[index] > max_logit) {
            max_logit = logits[index];
        }
    }

    double weights[256];
    double total = 0;
    for (int32_t index = 0; index < count; index++) {
        weights[index] = exp(logits[index] - max_logit);
        total += weights[index];
    }
    if (total <= 0) {
        return;
    }
    double current_log_probability = logits[transition->chosen_index] - (log(total) + max_logit);
    double log_ratio = current_log_probability - transition->old_log_probability;
    if (log_ratio > 20) log_ratio = 20;
    if (log_ratio < -20) log_ratio = -20;
    double ratio = exp(log_ratio);
    double clip = config.ppo_clip > 0 ? config.ppo_clip : 0.2;
    double update_weight = transition->update_weight > 0 ? transition->update_weight : 1.0;
    double advantage = transition->advantage * update_weight;
    bool outside_clip = ratio < 1.0 - clip || ratio > 1.0 + clip;
    double entropy = 0;
    for (int32_t index = 0; index < count; index++) {
        double probability = weights[index] / total;
        if (probability > 0) {
            entropy -= probability * log(probability);
        }
    }
    if (metrics) {
        double kl = transition->old_log_probability - current_log_probability;
        metrics->kl += kl;
        metrics->abs_kl += fabs(kl);
        metrics->entropy += entropy;
        metrics->clip_count += outside_clip ? 1 : 0;
        metrics->transition_count += 1;
    }
    if (config.entropy_weight > 0) {
        for (int32_t index = 0; index < count; index++) {
            if (!candidates[index].has_features) {
                continue;
            }
            double probability = weights[index] / total;
            if (probability <= 0) {
                continue;
            }
            double entropy_scale = update_weight * config.entropy_weight * (-probability * (log(probability) + entropy)) / safe_temperature;
            kc_add_cached_score_gradient(model, &candidates[index], entropy_scale, gradient);
        }
    }
    double imitation_weight = kc_imitation_weight_for_head(config, transition->action_head);
    if (imitation_weight > 0 && transition->teacher_index >= 0 && transition->teacher_index < count) {
        double imitation_scale = update_weight * imitation_weight / safe_temperature;
        if (candidates[transition->teacher_index].has_features) {
            kc_add_cached_score_gradient(model, &candidates[transition->teacher_index], imitation_scale, gradient);
        }
        for (int32_t index = 0; index < count; index++) {
            if (!candidates[index].has_features) {
                continue;
            }
            kc_add_cached_score_gradient(model, &candidates[index], -imitation_scale * (weights[index] / total), gradient);
        }
    }
    bool unclipped_active = advantage >= 0 ? ratio <= 1.0 + clip : ratio >= 1.0 - clip;
    if (!unclipped_active) {
        return;
    }

    double scale = ratio * advantage;
    if (candidates[transition->chosen_index].has_features) {
        kc_add_cached_score_gradient(model, &candidates[transition->chosen_index], scale / safe_temperature, gradient);
    }
    for (int32_t index = 0; index < count; index++) {
        if (!candidates[index].has_features) {
            continue;
        }
        kc_add_cached_score_gradient(model, &candidates[index], -scale * (weights[index] / total) / safe_temperature, gradient);
    }
}

static void kc_ppo_normalize_advantages(KCPPORollout *rollout) {
    if (rollout->transition_count <= 1) {
        return;
    }
    double mean = 0;
    for (int32_t index = 0; index < rollout->transition_count; index++) {
        mean += rollout->transitions[index].advantage;
    }
    mean /= (double)rollout->transition_count;
    double variance = 0;
    for (int32_t index = 0; index < rollout->transition_count; index++) {
        double centered = rollout->transitions[index].advantage - mean;
        variance += centered * centered;
    }
    variance /= (double)rollout->transition_count;
    double stddev = sqrt(variance);
    if (stddev < 1e-8) {
        return;
    }
    for (int32_t index = 0; index < rollout->transition_count; index++) {
        rollout->transitions[index].advantage = (rollout->transitions[index].advantage - mean) / stddev;
    }
}

static void kc_ppo_apply_phase_balance(KCPPORollout *rollout) {
    if (rollout->transition_count <= 0) {
        return;
    }
    int32_t head_counts[KC_SUIT_COUNT] = {0};
    int32_t present_heads = 0;
    for (int32_t index = 0; index < rollout->transition_count; index++) {
        int32_t head = rollout->transitions[index].action_head;
        if (head < 0 || head >= KC_SUIT_COUNT) {
            continue;
        }
        if (head_counts[head] == 0) {
            present_heads += 1;
        }
        head_counts[head] += 1;
    }
    if (present_heads <= 1) {
        return;
    }
    double total = (double)rollout->transition_count;
    for (int32_t index = 0; index < rollout->transition_count; index++) {
        int32_t head = rollout->transitions[index].action_head;
        if (head < 0 || head >= KC_SUIT_COUNT || head_counts[head] <= 0) {
            rollout->transitions[index].update_weight = 1.0;
            continue;
        }
        rollout->transitions[index].update_weight = total / ((double)present_heads * (double)head_counts[head]);
    }
}

static uint64_t kc_policy_episode_rng_seed(uint64_t seed, int32_t episode) {
    uint64_t value = seed + ((uint64_t)episode * 0x9E3779B97F4A7C15ULL);
    value ^= value >> 30;
    value *= 0xBF58476D1CE4E5B9ULL;
    value ^= value >> 27;
    value *= 0x94D049BB133111EBULL;
    value ^= value >> 31;
    return value == 0 ? 1 : value;
}

static void kc_policy_result_add_episode(KCPolicyGradientResult *result, const KCEpisodePolicyResult *episode_result) {
    result->episodes += 1;
    result->actions += episode_result->actions;
    result->checksum += episode_result->checksum;
    result->top_rate += episode_result->top_rate;
    result->average_rank += episode_result->average_rank;
    result->average_margin += episode_result->average_margin;
    result->average_reward += episode_result->average_reward;
    result->average_advantage += episode_result->average_advantage;
}

static void kc_policy_result_add(KCPolicyGradientResult *destination, const KCPolicyGradientResult *source) {
    destination->episodes += source->episodes;
    destination->actions += source->actions;
    destination->checksum += source->checksum;
    destination->top_rate += source->top_rate;
    destination->average_rank += source->average_rank;
    destination->average_margin += source->average_margin;
    destination->average_reward += source->average_reward;
    destination->average_advantage += source->average_advantage;
}

static int32_t kc_run_policy_gradient_episode(
    KCPolicyModelBuffer model,
    KCPolicyGradientConfig config,
    int32_t episode,
    uint64_t *rng_state,
    double **player_gradients,
    double *candidate_hidden_cache,
    double *seat_baselines,
    const double *value_weights,
    double *value_gradient,
    double *episode_value_features,
    double *episode_value_predictions,
    double *batch_gradient,
    KCEpisodePolicyResult *episode_result
) {
    memset(episode_result, 0, sizeof(*episode_result));
    int32_t param_count = kc_policy_parameter_count(model);
    KCEngine engine;
    KCVariants variants;
    kc_variants_kolkhoz(&variants);
    uint64_t episode_seed = config.seed + (uint64_t)episode;
    if (config.round_curriculum) {
        kc_engine_init_curriculum(&engine, episode_seed, variants, config.round_plot_cards, config.round_famine_rate);
    } else {
        kc_engine_init(&engine, episode_seed, variants);
    }
    int32_t starting_year = engine.year;
    int32_t training_seat = -1;
    if (config.has_opponent_model) {
        int32_t seat_count = config.training_seat_count;
        if (seat_count > KC_PLAYER_COUNT) seat_count = KC_PLAYER_COUNT;
        if (seat_count > 0) {
            int32_t scheduled = config.training_seats[(episode - 1) % seat_count];
            training_seat = scheduled >= 0 && scheduled < KC_PLAYER_COUNT ? scheduled : (episode - 1) % KC_PLAYER_COUNT;
        } else {
            training_seat = (episode - 1) % KC_PLAYER_COUNT;
        }
    }
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT * KC_SUIT_COUNT; player_id++) {
        memset(player_gradients[player_id], 0, (size_t)param_count * sizeof(double));
    }
    int32_t player_action_counts[KC_PLAYER_COUNT][KC_SUIT_COUNT] = {{0}};
    int32_t player_value_counts[KC_PLAYER_COUNT] = {0};
    int32_t guard_count = 0;
    KCPolicyActionCandidate *candidates = malloc(512 * sizeof(KCPolicyActionCandidate));
    if (!candidates) {
        return 2;
    }
    while (engine.phase != KC_PHASE_GAME_OVER && kc_curriculum_should_continue(&engine, config.round_curriculum, starting_year) && guard_count < 2000) {
        guard_count++;
        if (engine.phase == KC_PHASE_REQUISITION) {
            KCAction action = { .kind = KC_ACTION_CONTINUE_AFTER_REQUISITION, .player_id = 0, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            kc_engine_apply(&engine, action);
            continue;
        }
        int32_t player_id = engine.phase == KC_PHASE_ASSIGNMENT ? engine.last_winner : engine.current_player;
        KCAction selected;
        if (!config.has_opponent_model || player_id == training_seat) {
            int32_t count = kc_policy_candidates(&engine, player_id, model, candidates, 256, candidate_hidden_cache);
            int32_t action_head = count > 0 && candidates[0].action_head >= 0 && candidates[0].action_head < KC_SUIT_COUNT ? candidates[0].action_head : 2;
            if (config.value_learning_rate > 0 && value_weights && value_gradient && episode_value_features && episode_value_predictions && player_value_counts[player_id] < KC_MAX_POLICY_DECISIONS) {
                int32_t value_index = player_value_counts[player_id]++;
                double *features = episode_value_features + (((size_t)player_id * KC_MAX_POLICY_DECISIONS + value_index) * KC_VALUE_INPUT_SIZE);
                kc_value_features(&engine, player_id, action_head, features);
                episode_value_predictions[(size_t)player_id * KC_MAX_POLICY_DECISIONS + value_index] = kc_value_prediction(value_weights, features);
            }
            if (!kc_sample_policy_action(candidates, count, model, rng_state, config.temperature, config.greedy_sample_rate, player_gradients[player_id * KC_SUIT_COUNT + action_head], &selected)) {
                free(candidates);
                return 3;
            }
            player_action_counts[player_id][action_head] += 1;
        } else {
            bool ok = config.opponent_is_heuristic
                ? kc_heuristic_policy_action(&engine, &selected)
                : kc_greedy_policy_action(&engine, player_id, config.opponent_model, candidates + 256, candidate_hidden_cache, &selected);
            if (!ok) {
                free(candidates);
                return 3;
            }
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(candidates);
            return 10 + error;
        }
    }
    if (!config.round_curriculum && engine.phase != KC_PHASE_GAME_OVER) {
        free(candidates);
        return 4;
    }
    if (kc_curriculum_incomplete(&engine, config.round_curriculum, starting_year)) {
        free(candidates);
        return 4;
    }

    int32_t scores[KC_PLAYER_COUNT];
    int32_t medals[KC_PLAYER_COUNT];
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        scores[player_id] = kc_final_score(&engine, player_id);
        medals[player_id] = kc_total_medals_for_player(&engine, player_id);
    }
    int32_t episode_winner = engine.winner_id;
    if (episode_winner < 0) {
        episode_winner = 0;
        for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
            if (kc_player_beats_player(scores, medals, player_id, episode_winner)) {
                episode_winner = player_id;
            }
        }
    }
    double raw[KC_PLAYER_COUNT];
    double mean = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        raw[player_id] = kc_raw_reward_for_player(scores, medals, episode_winner, player_id, config);
        mean += raw[player_id];
    }
    mean /= KC_PLAYER_COUNT;
    double advantage_total = 0;
    if (config.has_opponent_model) {
        double target = raw[training_seat];
        if (config.paired_baseline) {
            int32_t baseline_scores[KC_PLAYER_COUNT];
            int32_t baseline_medals[KC_PLAYER_COUNT];
            int32_t baseline_winner = KC_NO_PLAYER;
            int32_t status = kc_run_greedy_matchup_game(
                episode_seed,
                variants,
                model,
                config.opponent_model,
                config.opponent_is_heuristic,
                training_seat,
                config.round_curriculum,
                config.round_plot_cards,
                config.round_famine_rate,
                baseline_scores,
                baseline_medals,
                &baseline_winner
            );
            if (status != 0) {
                free(candidates);
                return status;
            }
            target -= kc_raw_reward_for_player(baseline_scores, baseline_medals, baseline_winner, training_seat, config);
        }
        for (int32_t action_head = 0; action_head < KC_SUIT_COUNT; action_head++) {
            int32_t action_count = player_action_counts[training_seat][action_head];
            if (action_count <= 0) continue;
            double learned_baseline = 0;
            if (config.value_learning_rate > 0 && player_value_counts[training_seat] > 0 && value_gradient && episode_value_features && episode_value_predictions) {
                learned_baseline = kc_value_baseline_for_head(
                    training_seat,
                    action_head,
                    player_value_counts[training_seat],
                    target,
                    value_gradient,
                    episode_value_features,
                    episode_value_predictions
                );
            }
            double advantage = target - learned_baseline;
            int32_t baseline_index = training_seat * KC_SUIT_COUNT + action_head;
            double baseline = seat_baselines ? seat_baselines[baseline_index] : 0;
            if (seat_baselines && config.advantage_baseline_beta > 0) {
                seat_baselines[baseline_index] = baseline + config.advantage_baseline_beta * (advantage - baseline);
            }
            advantage -= baseline;
            advantage = kc_clip_advantage(advantage, config.advantage_clip);
            advantage_total += advantage;
            double scale = advantage / (double)action_count;
            kc_add_scaled(batch_gradient, player_gradients[training_seat * KC_SUIT_COUNT + action_head], param_count, scale);
        }
    } else {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            double target = raw[player_id] - mean;
            for (int32_t action_head = 0; action_head < KC_SUIT_COUNT; action_head++) {
                int32_t action_count = player_action_counts[player_id][action_head];
                if (action_count <= 0) continue;
                double learned_baseline = 0;
                if (config.value_learning_rate > 0 && player_value_counts[player_id] > 0 && value_gradient && episode_value_features && episode_value_predictions) {
                    learned_baseline = kc_value_baseline_for_head(
                        player_id,
                        action_head,
                        player_value_counts[player_id],
                        target,
                        value_gradient,
                        episode_value_features,
                        episode_value_predictions
                    );
                }
                double advantage = target - learned_baseline;
                advantage = kc_clip_advantage(advantage, config.advantage_clip);
                advantage_total += advantage;
                double scale = advantage / (double)action_count;
                kc_add_scaled(batch_gradient, player_gradients[player_id * KC_SUIT_COUNT + action_head], param_count, scale);
            }
        }
    }

    int32_t top_count = 0;
    int32_t rank_total = 0;
    int32_t margin_total = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        int32_t best_opponent = -1000000;
        for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
            if (other != player_id && scores[other] > best_opponent) {
                best_opponent = scores[other];
            }
        }
        if (episode_winner == player_id) top_count++;
        rank_total += kc_rank_for_player(scores, medals, player_id);
        margin_total += scores[player_id] - best_opponent;
    }
    int32_t episode_actions = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        for (int32_t action_head = 0; action_head < KC_SUIT_COUNT; action_head++) {
            episode_actions += player_action_counts[player_id][action_head];
        }
    }
    int32_t score_sum = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) score_sum += scores[player_id];

    int32_t metric_player = config.has_opponent_model && training_seat >= 0 ? training_seat : -1;
    int32_t metric_best_opponent = -1000000;
    if (metric_player >= 0) {
        for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
            if (other != metric_player && scores[other] > metric_best_opponent) {
                metric_best_opponent = scores[other];
            }
        }
    }
    episode_result->actions = episode_actions;
    episode_result->checksum = episode_winner * 31 + score_sum;
    episode_result->top_rate = metric_player >= 0 ? (episode_winner == metric_player ? 1.0 : 0.0) : (double)top_count / 4.0;
    episode_result->average_rank = metric_player >= 0 ? (double)kc_rank_for_player(scores, medals, metric_player) : (double)rank_total / 4.0;
    episode_result->average_margin = metric_player >= 0 ? (double)(scores[metric_player] - metric_best_opponent) : (double)margin_total / 4.0;
    episode_result->average_reward = metric_player >= 0 ? raw[metric_player] : mean;
    episode_result->average_advantage = config.has_opponent_model ? advantage_total : advantage_total / 4.0;
    free(candidates);
    return 0;
}

static void kc_ppo_assign_advantages_for_head(
    KCPPORollout *rollout,
    int32_t first_transition,
    int32_t last_transition,
    int32_t player_id,
    int32_t action_head,
    double target,
    double *seat_baselines,
    double *value_gradient,
    KCPolicyGradientConfig config,
    double *advantage_total
) {
    int32_t matched = 0;
    double mean_advantage = 0;
    for (int32_t index = first_transition; index < last_transition; index++) {
        KCPPORolloutTransition *transition = &rollout->transitions[index];
        if (transition->player_id != player_id || transition->action_head != action_head) {
            continue;
        }
        matched++;
        double prediction = (value_gradient && config.value_learning_rate > 0) ? transition->value_prediction : 0.0;
        mean_advantage += target - prediction;
    }
    if (matched <= 0) {
        return;
    }
    mean_advantage /= (double)matched;
    int32_t baseline_index = player_id * KC_SUIT_COUNT + action_head;
    double baseline = seat_baselines ? seat_baselines[baseline_index] : 0;
    if (seat_baselines && config.advantage_baseline_beta > 0) {
        seat_baselines[baseline_index] = baseline + config.advantage_baseline_beta * (mean_advantage - baseline);
    }
    double shared_advantage = kc_clip_advantage(mean_advantage - baseline, config.advantage_clip);
    for (int32_t index = first_transition; index < last_transition; index++) {
        KCPPORolloutTransition *transition = &rollout->transitions[index];
        if (transition->player_id != player_id || transition->action_head != action_head) {
            continue;
        }
        double advantage = shared_advantage;
        if (config.per_transition_value_advantages) {
            double prediction = (value_gradient && config.value_learning_rate > 0) ? transition->value_prediction : 0.0;
            advantage = target - prediction - baseline;
            advantage = kc_clip_advantage(advantage, config.advantage_clip);
        }
        advantage += transition->shaped_reward;
        transition->advantage = advantage;
        *advantage_total += advantage;
        if (value_gradient && config.value_learning_rate > 0) {
            kc_add_value_gradient(value_gradient, transition->value_features, target - transition->value_prediction);
        }
    }
}

static int32_t kc_run_policy_ppo_episode(
    KCPolicyModelBuffer model,
    KCPolicyGradientConfig config,
    int32_t episode,
    uint64_t *rng_state,
    double *candidate_hidden_cache,
    double *seat_baselines,
    const double *value_weights,
    double *value_gradient,
    KCPPORollout *rollout,
    KCEpisodePolicyResult *episode_result
) {
    memset(episode_result, 0, sizeof(*episode_result));
    KCEngine engine;
    KCVariants variants;
    kc_variants_kolkhoz(&variants);
    uint64_t episode_seed = config.seed + (uint64_t)episode;
    if (config.round_curriculum) {
        kc_engine_init_curriculum(&engine, episode_seed, variants, config.round_plot_cards, config.round_famine_rate);
    } else {
        kc_engine_init(&engine, episode_seed, variants);
    }
    int32_t starting_year = engine.year;
    int32_t training_seat = -1;
    if (config.has_opponent_model) {
        int32_t seat_count = config.training_seat_count;
        if (seat_count > KC_PLAYER_COUNT) seat_count = KC_PLAYER_COUNT;
        if (seat_count > 0) {
            int32_t scheduled = config.training_seats[(episode - 1) % seat_count];
            training_seat = scheduled >= 0 && scheduled < KC_PLAYER_COUNT ? scheduled : (episode - 1) % KC_PLAYER_COUNT;
        } else {
            training_seat = (episode - 1) % KC_PLAYER_COUNT;
        }
    }

    int32_t first_transition = rollout->transition_count;
    int32_t player_action_counts[KC_PLAYER_COUNT][KC_SUIT_COUNT] = {{0}};
    int32_t guard_count = 0;
    bool shaped_rewards = kc_has_shaped_rewards(config);
    KCPolicyActionCandidate *candidates = malloc(512 * sizeof(KCPolicyActionCandidate));
    if (!candidates) {
        return 2;
    }
    while (engine.phase != KC_PHASE_GAME_OVER && kc_curriculum_should_continue(&engine, config.round_curriculum, starting_year) && guard_count < 2000) {
        guard_count++;
        if (engine.phase == KC_PHASE_REQUISITION) {
            KCAction action = { .kind = KC_ACTION_CONTINUE_AFTER_REQUISITION, .player_id = 0, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            kc_engine_apply(&engine, action);
            continue;
        }
        int32_t player_id = engine.phase == KC_PHASE_ASSIGNMENT ? engine.last_winner : engine.current_player;
        KCAction selected;
        int32_t transition_index = -1;
        int32_t shaped_player_id = -1;
        int32_t before_score = 0;
        int32_t before_margin = 0;
        int32_t before_work = 0;
        int32_t before_claims = 0;
        int32_t before_requisitions = 0;
        if (!config.has_opponent_model || player_id == training_seat) {
            if (shaped_rewards) {
                shaped_player_id = player_id;
                before_score = kc_final_score(&engine, player_id);
                before_margin = kc_score_margin_for_player(&engine, player_id);
                before_work = kc_total_work_hours(&engine);
                before_claims = kc_claimed_job_count(&engine);
                before_requisitions = kc_own_requisition_count(&engine, player_id);
            }
            int32_t count = kc_policy_candidates(&engine, player_id, model, candidates, 256, candidate_hidden_cache);
            int32_t action_head = count > 0 && candidates[0].action_head >= 0 && candidates[0].action_head < KC_SUIT_COUNT ? candidates[0].action_head : 2;
            int32_t chosen = 0;
            double old_log_probability = 0;
            if (!kc_sample_policy_choice(candidates, count, rng_state, config.temperature, config.greedy_sample_rate, &chosen, &old_log_probability)) {
                free(candidates);
                return 3;
            }
            double value_features[KC_VALUE_INPUT_SIZE] = {0};
            double value_prediction = 0;
            if (config.value_learning_rate > 0 && value_weights) {
                kc_value_features(&engine, player_id, action_head, value_features);
                value_prediction = kc_value_prediction(value_weights, value_features);
            }
            int32_t teacher_index = -1;
            if (kc_imitation_weight_for_head(config, action_head) > 0 && config.has_opponent_model) {
                KCAction teacher_action;
                bool teacher_ok = kc_greedy_policy_action(&engine, player_id, config.opponent_model, candidates + 256, candidate_hidden_cache, &teacher_action);
                if (teacher_ok) {
                    teacher_index = kc_policy_candidate_index_for_action(candidates, count, teacher_action);
                }
            }
            if (teacher_index >= 0 && config.teacher_forcing_rate > 0 && kc_uniform_from_state(rng_state) < config.teacher_forcing_rate) {
                chosen = teacher_index;
                old_log_probability = kc_policy_choice_log_probability(candidates, count, chosen, config.temperature);
            }
            if (!kc_ppo_rollout_append(rollout, candidates, count, chosen, old_log_probability, player_id, action_head, value_features, value_prediction, teacher_index)) {
                free(candidates);
                return 2;
            }
            transition_index = rollout->transition_count - 1;
            selected = candidates[chosen].action;
            player_action_counts[player_id][action_head] += 1;
        } else {
            bool ok = config.opponent_is_heuristic
                ? kc_heuristic_policy_action(&engine, &selected)
                : kc_greedy_policy_action(&engine, player_id, config.opponent_model, candidates + 256, candidate_hidden_cache, &selected);
            if (!ok) {
                free(candidates);
                return 3;
            }
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(candidates);
            return 10 + error;
        }
        if (transition_index >= 0 && shaped_player_id >= 0) {
            rollout->transitions[transition_index].shaped_reward = kc_shaped_reward_delta(
                &engine,
                shaped_player_id,
                before_score,
                before_margin,
                before_work,
                before_claims,
                before_requisitions,
                config
            );
        }
    }
    if (!config.round_curriculum && engine.phase != KC_PHASE_GAME_OVER) {
        free(candidates);
        return 4;
    }
    if (kc_curriculum_incomplete(&engine, config.round_curriculum, starting_year)) {
        free(candidates);
        return 4;
    }

    int32_t scores[KC_PLAYER_COUNT];
    int32_t medals[KC_PLAYER_COUNT];
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        scores[player_id] = kc_final_score(&engine, player_id);
        medals[player_id] = kc_total_medals_for_player(&engine, player_id);
    }
    int32_t episode_winner = engine.winner_id;
    if (episode_winner < 0) {
        episode_winner = 0;
        for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
            if (kc_player_beats_player(scores, medals, player_id, episode_winner)) {
                episode_winner = player_id;
            }
        }
    }
    double raw[KC_PLAYER_COUNT];
    double mean = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        raw[player_id] = kc_raw_reward_for_player(scores, medals, episode_winner, player_id, config);
        mean += raw[player_id];
    }
    mean /= KC_PLAYER_COUNT;

    int32_t last_transition = rollout->transition_count;
    double advantage_total = 0;
    if (config.has_opponent_model) {
        double target = raw[training_seat];
        if (config.paired_baseline) {
            int32_t baseline_scores[KC_PLAYER_COUNT];
            int32_t baseline_medals[KC_PLAYER_COUNT];
            int32_t baseline_winner = KC_NO_PLAYER;
            int32_t status = kc_run_greedy_matchup_game(
                episode_seed,
                variants,
                model,
                config.opponent_model,
                config.opponent_is_heuristic,
                training_seat,
                config.round_curriculum,
                config.round_plot_cards,
                config.round_famine_rate,
                baseline_scores,
                baseline_medals,
                &baseline_winner
            );
            if (status != 0) {
                free(candidates);
                return status;
            }
            target -= kc_raw_reward_for_player(baseline_scores, baseline_medals, baseline_winner, training_seat, config);
        }
        for (int32_t action_head = 0; action_head < KC_SUIT_COUNT; action_head++) {
            kc_ppo_assign_advantages_for_head(
                rollout,
                first_transition,
                last_transition,
                training_seat,
                action_head,
                target,
                seat_baselines,
                value_gradient,
                config,
                &advantage_total
            );
        }
    } else {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            double target = raw[player_id] - mean;
            for (int32_t action_head = 0; action_head < KC_SUIT_COUNT; action_head++) {
                kc_ppo_assign_advantages_for_head(
                    rollout,
                    first_transition,
                    last_transition,
                    player_id,
                    action_head,
                    target,
                    seat_baselines,
                    value_gradient,
                    config,
                    &advantage_total
                );
            }
        }
    }

    int32_t top_count = 0;
    int32_t rank_total = 0;
    int32_t margin_total = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        int32_t best_opponent = -1000000;
        for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
            if (other != player_id && scores[other] > best_opponent) {
                best_opponent = scores[other];
            }
        }
        if (episode_winner == player_id) top_count++;
        rank_total += kc_rank_for_player(scores, medals, player_id);
        margin_total += scores[player_id] - best_opponent;
    }
    int32_t episode_actions = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        for (int32_t action_head = 0; action_head < KC_SUIT_COUNT; action_head++) {
            episode_actions += player_action_counts[player_id][action_head];
        }
    }
    int32_t score_sum = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) score_sum += scores[player_id];

    int32_t metric_player = config.has_opponent_model && training_seat >= 0 ? training_seat : -1;
    int32_t metric_best_opponent = -1000000;
    if (metric_player >= 0) {
        for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
            if (other != metric_player && scores[other] > metric_best_opponent) {
                metric_best_opponent = scores[other];
            }
        }
    }
    episode_result->actions = episode_actions;
    episode_result->checksum = episode_winner * 31 + score_sum;
    episode_result->top_rate = metric_player >= 0 ? (episode_winner == metric_player ? 1.0 : 0.0) : (double)top_count / 4.0;
    episode_result->average_rank = metric_player >= 0 ? (double)kc_rank_for_player(scores, medals, metric_player) : (double)rank_total / 4.0;
    episode_result->average_margin = metric_player >= 0 ? (double)(scores[metric_player] - metric_best_opponent) : (double)margin_total / 4.0;
    episode_result->average_reward = metric_player >= 0 ? raw[metric_player] : mean;
    episode_result->average_advantage = config.has_opponent_model ? advantage_total : advantage_total / 4.0;
    free(candidates);
    return 0;
}

static int32_t kc_train_policy_gradient_ppo(KCPolicyModelBuffer model, KCPolicyGradientConfig config, KCPolicyGradientResult *result) {
    memset(result, 0, sizeof(*result));
    int32_t param_count = kc_policy_parameter_count(model);
    double *batch_gradient = calloc((size_t)param_count, sizeof(double));
    double *adam_m = config.use_adam ? calloc((size_t)param_count, sizeof(double)) : NULL;
    double *adam_v = config.use_adam ? calloc((size_t)param_count, sizeof(double)) : NULL;
    double *candidate_hidden_cache = malloc((size_t)256 * (size_t)kc_policy_activation_count(model) * sizeof(double));
    int32_t *transition_indices = NULL;
    int32_t transition_index_capacity = 0;
    bool owns_value_weights = config.value_weights == NULL;
    double *value_weights = owns_value_weights ? calloc(KC_VALUE_INPUT_SIZE, sizeof(double)) : config.value_weights;
    double *batch_value_gradient = calloc(KC_VALUE_INPUT_SIZE, sizeof(double));
    if (!batch_gradient || (config.use_adam && (!adam_m || !adam_v)) || !candidate_hidden_cache || !value_weights || !batch_value_gradient) {
        free(batch_gradient);
        free(adam_m);
        free(adam_v);
        free(candidate_hidden_cache);
        free(transition_indices);
        if (owns_value_weights) free(value_weights);
        free(batch_value_gradient);
        return 2;
    }

    KCPPORollout rollout;
    kc_ppo_rollout_init(&rollout);
    double seat_baselines[KC_PLAYER_COUNT * KC_SUIT_COUNT] = {0};
    KCPPOMetrics metrics = {0};
    int32_t status = 0;
    int32_t epochs = config.ppo_epochs > 0 ? config.ppo_epochs : 4;
    int32_t adam_timestep = 0;
    for (int32_t batch_start = 1; batch_start <= config.episodes && status == 0; batch_start += config.batch_size) {
        int32_t batch_end = batch_start + config.batch_size - 1;
        if (batch_end > config.episodes) batch_end = config.episodes;
        kc_ppo_rollout_clear(&rollout);
        memset(batch_value_gradient, 0, KC_VALUE_INPUT_SIZE * sizeof(double));
        for (int32_t episode = batch_start; episode <= batch_end; episode++) {
            uint64_t rng_state = kc_policy_episode_rng_seed(config.seed, episode);
            KCEpisodePolicyResult episode_result;
            status = kc_run_policy_ppo_episode(
                model,
                config,
                episode,
                &rng_state,
                candidate_hidden_cache,
                seat_baselines,
                value_weights,
                batch_value_gradient,
                &rollout,
                &episode_result
            );
            if (status != 0) {
                break;
            }
            kc_policy_result_add_episode(result, &episode_result);
        }
        if (status != 0) {
            break;
        }
        if (rollout.transition_count <= 0) {
            status = 3;
            break;
        }
        if (rollout.transition_count > transition_index_capacity) {
            int32_t *new_indices = realloc(transition_indices, (size_t)rollout.transition_count * sizeof(int32_t));
            if (!new_indices) {
                status = 2;
                break;
            }
            transition_indices = new_indices;
            transition_index_capacity = rollout.transition_count;
        }
        kc_ppo_normalize_advantages(&rollout);
        if (config.phase_balanced_ppo) {
            kc_ppo_apply_phase_balance(&rollout);
        }

        double norm = 0;
        double scale = 1;
        int32_t minibatch_size = config.ppo_minibatch_size > 0 ? config.ppo_minibatch_size : rollout.transition_count;
        if (minibatch_size > rollout.transition_count) {
            minibatch_size = rollout.transition_count;
        }
        uint64_t replay_rng = kc_policy_episode_rng_seed(config.seed ^ 0xD1B54A32D192ED03ULL, batch_start);
        for (int32_t epoch = 0; epoch < epochs; epoch++) {
            kc_shuffle_transition_indices(&replay_rng, transition_indices, rollout.transition_count);
            for (int32_t start = 0; start < rollout.transition_count; start += minibatch_size) {
                int32_t end = start + minibatch_size;
                if (end > rollout.transition_count) end = rollout.transition_count;
                int32_t divisor = end - start;
                memset(batch_gradient, 0, (size_t)param_count * sizeof(double));
                for (int32_t order_index = start; order_index < end; order_index++) {
                    int32_t transition_index = transition_indices[order_index];
                    kc_add_ppo_transition_gradient(
                        model,
                        config,
                        &rollout,
                        &rollout.transitions[transition_index],
                        candidate_hidden_cache,
                        batch_gradient,
                        &metrics
                    );
                }
                if (config.use_adam) {
                    adam_timestep += 1;
                    kc_apply_adam_gradient_to_model(model, batch_gradient, config, divisor, adam_m, adam_v, adam_timestep, &norm, &scale);
                } else {
                    kc_apply_gradient_to_model(model, batch_gradient, config, divisor, &norm, &scale);
                }
            }
        }

        if (config.value_learning_rate > 0) {
            double value_step = config.value_learning_rate / (double)(rollout.transition_count > 0 ? rollout.transition_count : 1);
            for (int32_t index = 0; index < KC_VALUE_INPUT_SIZE; index++) {
                value_weights[index] += value_step * batch_value_gradient[index] - config.value_learning_rate * config.l2 * value_weights[index];
            }
        }
        result->batches += 1;
        result->last_gradient_norm = norm;
        result->last_clip_scale = scale;
    }

    if (status == 0 && result->episodes > 0) {
        result->top_rate /= (double)result->episodes;
        result->average_rank /= (double)result->episodes;
        result->average_margin /= (double)result->episodes;
        result->average_reward /= (double)result->episodes;
        result->average_advantage /= (double)result->episodes;
        if (metrics.transition_count > 0) {
            result->average_ppo_kl = metrics.kl / (double)metrics.transition_count;
            result->average_ppo_abs_kl = metrics.abs_kl / (double)metrics.transition_count;
            result->average_ppo_entropy = metrics.entropy / (double)metrics.transition_count;
            result->average_ppo_clip_fraction = (double)metrics.clip_count / (double)metrics.transition_count;
        }
        result->weight_checksum = kc_policy_weight_checksum(model, value_weights);
    }
    kc_ppo_rollout_free(&rollout);
    free(batch_value_gradient);
    if (owns_value_weights) free(value_weights);
    free(adam_m);
    free(adam_v);
    free(transition_indices);
    free(candidate_hidden_cache);
    free(batch_gradient);
    return status;
}

typedef struct {
    KCPolicyModelBuffer model;
    KCPolicyGradientConfig config;
    int32_t batch_start;
    int32_t batch_end;
    int32_t thread_index;
    int32_t thread_count;
    int32_t param_count;
    double *gradient;
    const double *value_weights;
    double *value_gradient;
    KCPolicyGradientResult result;
    int32_t status;
} KCPolicyBatchWorker;

static void *kc_policy_batch_worker_main(void *raw_context) {
    KCPolicyBatchWorker *context = (KCPolicyBatchWorker *)raw_context;
    context->status = 0;
    memset(&context->result, 0, sizeof(context->result));
    context->gradient = calloc((size_t)context->param_count, sizeof(double));
    if (!context->gradient) {
        context->status = 2;
        return NULL;
    }
    context->value_gradient = calloc(KC_VALUE_INPUT_SIZE, sizeof(double));
    if (!context->value_gradient) {
        context->status = 2;
        free(context->gradient);
        context->gradient = NULL;
        return NULL;
    }
    double *player_gradients[KC_PLAYER_COUNT * KC_SUIT_COUNT];
    for (int32_t gradient_index = 0; gradient_index < KC_PLAYER_COUNT * KC_SUIT_COUNT; gradient_index++) {
        player_gradients[gradient_index] = calloc((size_t)context->param_count, sizeof(double));
        if (!player_gradients[gradient_index]) {
            context->status = 2;
            for (int32_t i = 0; i < gradient_index; i++) free(player_gradients[i]);
            free(context->value_gradient);
            free(context->gradient);
            context->value_gradient = NULL;
            context->gradient = NULL;
            return NULL;
        }
    }
    double *candidate_hidden_cache = malloc((size_t)256 * (size_t)kc_policy_activation_count(context->model) * sizeof(double));
    if (!candidate_hidden_cache) {
        context->status = 2;
        for (int32_t i = 0; i < KC_PLAYER_COUNT * KC_SUIT_COUNT; i++) free(player_gradients[i]);
        free(context->value_gradient);
        free(context->gradient);
        context->value_gradient = NULL;
        context->gradient = NULL;
        return NULL;
    }
    double *episode_value_features = calloc((size_t)KC_PLAYER_COUNT * KC_MAX_POLICY_DECISIONS * KC_VALUE_INPUT_SIZE, sizeof(double));
    double *episode_value_predictions = calloc((size_t)KC_PLAYER_COUNT * KC_MAX_POLICY_DECISIONS, sizeof(double));
    if (!episode_value_features || !episode_value_predictions) {
        context->status = 2;
        free(episode_value_features);
        free(episode_value_predictions);
        free(candidate_hidden_cache);
        for (int32_t i = 0; i < KC_PLAYER_COUNT * KC_SUIT_COUNT; i++) free(player_gradients[i]);
        free(context->value_gradient);
        free(context->gradient);
        context->value_gradient = NULL;
        context->gradient = NULL;
        return NULL;
    }

    double seat_baselines[KC_PLAYER_COUNT * KC_SUIT_COUNT] = {0};
    for (int32_t episode = context->batch_start + context->thread_index; episode <= context->batch_end; episode += context->thread_count) {
        uint64_t rng_state = kc_policy_episode_rng_seed(context->config.seed, episode);
        KCEpisodePolicyResult episode_result;
        int32_t status = kc_run_policy_gradient_episode(
            context->model,
            context->config,
            episode,
            &rng_state,
            player_gradients,
            candidate_hidden_cache,
            seat_baselines,
            context->value_weights,
            context->value_gradient,
            episode_value_features,
            episode_value_predictions,
            context->gradient,
            &episode_result
        );
        if (status != 0) {
            context->status = status;
            break;
        }
        kc_policy_result_add_episode(&context->result, &episode_result);
    }

    free(episode_value_features);
    free(episode_value_predictions);
    free(candidate_hidden_cache);
    for (int32_t i = 0; i < KC_PLAYER_COUNT * KC_SUIT_COUNT; i++) free(player_gradients[i]);
    return NULL;
}

static int32_t kc_train_policy_gradient_parallel(KCPolicyModelBuffer model, KCPolicyGradientConfig config, KCPolicyGradientResult *result) {
    memset(result, 0, sizeof(*result));
    int32_t param_count = kc_policy_parameter_count(model);
    double *batch_gradient = calloc((size_t)param_count, sizeof(double));
    if (!batch_gradient) {
        return 2;
    }
    bool owns_value_weights = config.value_weights == NULL;
    double *value_weights = owns_value_weights ? calloc(KC_VALUE_INPUT_SIZE, sizeof(double)) : config.value_weights;
    double *batch_value_gradient = calloc(KC_VALUE_INPUT_SIZE, sizeof(double));
    if (!value_weights || !batch_value_gradient) {
        if (owns_value_weights) free(value_weights);
        free(batch_value_gradient);
        free(batch_gradient);
        return 2;
    }
    int32_t requested_threads = config.thread_count > 1 ? config.thread_count : 1;
    for (int32_t batch_start = 1; batch_start <= config.episodes; batch_start += config.batch_size) {
        int32_t batch_end = batch_start + config.batch_size - 1;
        if (batch_end > config.episodes) batch_end = config.episodes;
        int32_t batch_count = batch_end - batch_start + 1;
        int32_t thread_count = requested_threads < batch_count ? requested_threads : batch_count;
        pthread_t *threads = calloc((size_t)thread_count, sizeof(pthread_t));
        KCPolicyBatchWorker *workers = calloc((size_t)thread_count, sizeof(KCPolicyBatchWorker));
        if (!threads || !workers) {
            free(threads);
            free(workers);
            free(batch_value_gradient);
            if (owns_value_weights) free(value_weights);
            free(batch_gradient);
            return 2;
        }
        int32_t created_threads = 0;
        int32_t status = 0;
        for (int32_t thread_index = 0; thread_index < thread_count; thread_index++) {
            workers[thread_index] = (KCPolicyBatchWorker){
                .model = model,
                .config = config,
                .batch_start = batch_start,
                .batch_end = batch_end,
                .thread_index = thread_index,
                .thread_count = thread_count,
                .param_count = param_count,
                .gradient = NULL,
                .value_weights = value_weights,
                .value_gradient = NULL,
                .result = {0},
                .status = 0
            };
            int32_t error = pthread_create(&threads[thread_index], NULL, kc_policy_batch_worker_main, &workers[thread_index]);
            if (error != 0) {
                status = 5;
                break;
            }
            created_threads++;
        }
        for (int32_t thread_index = 0; thread_index < created_threads; thread_index++) {
            pthread_join(threads[thread_index], NULL);
        }
        if (status == 0) {
            for (int32_t thread_index = 0; thread_index < created_threads; thread_index++) {
                if (workers[thread_index].status != 0) {
                    status = workers[thread_index].status;
                    break;
                }
            }
        }
        if (status == 0) {
            for (int32_t thread_index = 0; thread_index < created_threads; thread_index++) {
                kc_add_scaled(batch_gradient, workers[thread_index].gradient, param_count, 1.0);
                if (workers[thread_index].value_gradient) {
                    kc_add_scaled(batch_value_gradient, workers[thread_index].value_gradient, KC_VALUE_INPUT_SIZE, 1.0);
                }
                kc_policy_result_add(result, &workers[thread_index].result);
            }
            double norm = 0;
            double scale = 1;
            kc_apply_gradient_to_model(model, batch_gradient, config, batch_count, &norm, &scale);
            if (config.value_learning_rate > 0) {
                double value_step = config.value_learning_rate / (double)(batch_count > 0 ? batch_count : 1);
                for (int32_t index = 0; index < KC_VALUE_INPUT_SIZE; index++) {
                    value_weights[index] += value_step * batch_value_gradient[index] - config.value_learning_rate * config.l2 * value_weights[index];
                }
            }
            result->batches += 1;
            result->last_gradient_norm = norm;
            result->last_clip_scale = scale;
            memset(batch_gradient, 0, (size_t)param_count * sizeof(double));
            memset(batch_value_gradient, 0, KC_VALUE_INPUT_SIZE * sizeof(double));
        }
        for (int32_t thread_index = 0; thread_index < created_threads; thread_index++) {
            free(workers[thread_index].gradient);
            free(workers[thread_index].value_gradient);
        }
        free(workers);
        free(threads);
        if (status != 0) {
            free(batch_value_gradient);
            if (owns_value_weights) free(value_weights);
            free(batch_gradient);
            return status;
        }
    }
    if (result->episodes > 0) {
        result->top_rate /= (double)result->episodes;
        result->average_rank /= (double)result->episodes;
        result->average_margin /= (double)result->episodes;
        result->average_reward /= (double)result->episodes;
        result->average_advantage /= (double)result->episodes;
    }
    result->weight_checksum = kc_policy_weight_checksum(model, value_weights);
    free(batch_value_gradient);
    if (owns_value_weights) free(value_weights);
    free(batch_gradient);
    return 0;
}

int32_t kc_train_policy_gradient(KCPolicyModelBuffer model, KCPolicyGradientConfig config, KCPolicyGradientResult *result) {
    if (model.input_size != KC_POLICY_INPUT_SIZE || model.hidden_size <= 0 || config.episodes <= 0 || config.batch_size <= 0) {
        return 1;
    }
    if (model.layer_count < 0 || model.layer_count > KC_MAX_POLICY_HIDDEN_LAYERS || kc_policy_parameter_count(model) <= 0 || kc_policy_activation_count(model) <= 0) {
        return 1;
    }
    if (kc_policy_activation_count(model) > KC_MAX_POLICY_ACTIVATIONS) {
        return 1;
    }
    if (config.use_ppo) {
        return kc_train_policy_gradient_ppo(model, config, result);
    }
    return kc_train_policy_gradient_parallel(model, config, result);
}

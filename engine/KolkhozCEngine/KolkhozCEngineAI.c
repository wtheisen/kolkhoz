#include "KolkhozCEngineInternal.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

static int32_t kc_pending_assignment_work_for_suit(const KCEngine *engine, int32_t suit) {
    int32_t work = 0;
    if (!engine || !kc_valid_suit(suit)) {
        return work;
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (engine->pending_assignment_targets[i] == suit) {
            work += kc_work_value(engine, engine->last_trick[i].card);
        }
    }
    return work;
}

static bool kc_pending_assignment_has_wrecker_for_suit(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) {
        return false;
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (engine->pending_assignment_targets[i] == suit &&
            kc_card_is_wrecker(engine->last_trick[i].card)) {
            return true;
        }
    }
    return false;
}

static int32_t kc_benchmark_plot_risk_count(const KCEngine *engine, int32_t player_id, int32_t suit) {
    if (!engine || !kc_valid_player_id(player_id) || !kc_valid_suit(suit)) {
        return 0;
    }
    const KCPlayer *player = &engine->players[player_id];
    int32_t count = 0;
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        if (kc_card_matches_suit(player->plot_revealed.cards[i], suit)) {
            count++;
        }
    }
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        if (kc_card_matches_suit(player->plot_hidden.cards[i], suit)) {
            count++;
        }
    }
    return count;
}

static int32_t kc_benchmark_job_value(const KCEngine *engine, int32_t suit, int32_t player_id) {
    if (!engine || !kc_valid_suit(suit)) {
        return 0;
    }
    if (engine->claimed_jobs[suit]) {
        return -10;
    }
    int32_t remaining = KC_WORK_THRESHOLD - engine->work_hours[suit];
    if (remaining < 0) {
        remaining = 0;
    }
    int32_t score = remaining < 20 ? (20 - remaining) * 2 : 0;
    score += kc_benchmark_plot_risk_count(engine, player_id, suit) * 15;
    if (engine->has_revealed_job[suit]) {
        score += engine->revealed_jobs[suit].value * 3;
    }
    return score;
}

static int32_t kc_benchmark_win_desire(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) {
        return 0;
    }
    const KCPlayer *player = &engine->players[player_id];
    int32_t desire = 0;
    if (!player->has_won_trick_this_year &&
        (player->plot_revealed.count + player->plot_hidden.count) > 0) {
        desire -= 300;
    }
    bool seen[KC_SUIT_COUNT] = {0};
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
            if (!seen[suit] && kc_card_matches_suit(engine->current_trick[i].card, suit)) {
                seen[suit] = true;
                desire += kc_benchmark_job_value(engine, suit, player_id);
            }
        }
    }
    if (player->brigade_leader) {
        desire += 50;
    }
    if (engine->trick_count >= 2) {
        desire += 30;
    }
    return desire;
}

static int32_t kc_benchmark_trump_score(const KCEngine *engine, KCAction action) {
    if (!engine || !kc_valid_suit(action.suit) || !kc_valid_player_id(action.player_id)) {
        return 0;
    }
    const KCPlayer *player = &engine->players[action.player_id];
    int32_t count = 0;
    int32_t total = 0;
    int32_t high_cards = 0;
    for (int32_t i = 0; i < player->hand.count; i++) {
        KCCard card = player->hand.cards[i];
        if (card.suit == action.suit) {
            count++;
            total += card.value;
            if (card.value >= 10) {
                high_cards++;
            }
        }
    }
    int32_t risk = kc_benchmark_plot_risk_count(engine, action.player_id, action.suit);
    int32_t job_bonus = engine->work_hours[action.suit] >= 20 &&
        engine->work_hours[action.suit] < KC_WORK_THRESHOLD ? 30 : 0;
    return count * 40 + total * 3 + high_cards * 35 + job_bonus - risk * 24;
}

static int32_t kc_benchmark_swap_score(const KCEngine *engine, KCAction action) {
    if (!engine ||
        action.kind != KC_ACTION_SWAP ||
        !kc_card_valid(action.hand_card) ||
        !kc_card_valid(action.plot_card)) {
        return -100000;
    }
    int32_t score = (action.plot_card.value - action.hand_card.value) * 20;
    bool hand_complete = kc_valid_suit(action.hand_card.suit) &&
        engine->claimed_jobs[action.hand_card.suit];
    bool plot_complete = kc_valid_suit(action.plot_card.suit) &&
        engine->claimed_jobs[action.plot_card.suit];
    if (hand_complete && !plot_complete) {
        score += 100;
    }
    if (plot_complete && !hand_complete) {
        score -= 100;
    }
    if (kc_valid_suit(action.hand_card.suit) &&
        engine->work_hours[action.hand_card.suit] >= 30) {
        score += 50;
    }
    if (kc_valid_suit(action.plot_card.suit) &&
        engine->work_hours[action.plot_card.suit] >= 30) {
        score -= 50;
    }
    if (engine->trump >= 0 && kc_card_matches_suit(action.hand_card, engine->trump)) {
        score -= 150;
    }
    if (engine->trump >= 0 && kc_card_matches_suit(action.plot_card, engine->trump)) {
        score += 150;
    }
    if (action.hand_card.value >= 11) {
        score -= 80;
    }
    if (action.plot_card.value >= 11) {
        score += 80;
    }
    if (action.plot_zone == KC_ZONE_HIDDEN) {
        score += 20;
    }
    if (kc_card_is_wrecker(action.hand_card)) {
        score -= 250;
    }
    if (kc_card_is_wrecker(action.plot_card)) {
        score += 250;
    }
    return score;
}

static int32_t kc_benchmark_play_score(const KCEngine *engine, KCAction action) {
    KCCard card = action.card;
    if (!engine || !kc_card_valid(card)) {
        return 0;
    }
    int32_t value = kc_work_value(engine, card);
    int32_t score = -value;
    bool wrecker = kc_card_is_wrecker(card);
    bool trump = engine->trump >= 0 && kc_card_matches_suit(card, engine->trump);
    if (engine->current_trick_count <= 0) {
        int32_t job_value = card.suit >= 0 && card.suit < KC_SUIT_COUNT ?
            kc_benchmark_job_value(engine, card.suit, action.player_id) : 0;
        score = job_value * 3 - value * 4;
        if (value >= 8 && value <= 11) {
            score += 20;
        }
        if (trump) {
            score -= engine->trick_count < 2 ? 60 : 20;
        }
    } else {
        bool winning = kc_would_currently_win(engine, card);
        int32_t desire = kc_benchmark_win_desire(engine, action.player_id);
        int32_t lead_suit = kc_lead_suit(engine);
        if (winning) {
            score = desire + (engine->current_trick_count >= KC_PLAYER_COUNT - 1 ? 80 : 20) - value * 3;
        } else {
            score = -desire / 2 + 30 - value;
        }
        if (lead_suit >= 0 && !kc_card_matches_suit(card, lead_suit)) {
            for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                if (kc_card_matches_suit(card, suit) && !engine->claimed_jobs[suit]) {
                    score += kc_benchmark_plot_risk_count(engine, action.player_id, suit) * 12;
                }
            }
        }
        if (trump && !winning) {
            score -= 80;
        }
    }
    if (wrecker) {
        score -= 400;
    }
    return score;
}

static int32_t kc_benchmark_assignment_card_score(
    const KCEngine *engine,
    KCCard card,
    int32_t target,
    int32_t player_id,
    const int32_t added_work[KC_SUIT_COUNT],
    const bool planned_wrecker[KC_SUIT_COUNT]
) {
    if (!engine || !kc_valid_suit(target)) {
        return -100000;
    }
    int32_t current_work = engine->work_hours[target] +
        kc_pending_assignment_work_for_suit(engine, target) +
        (added_work ? added_work[target] : 0);
    int32_t card_work = kc_work_value(engine, card);
    bool has_wrecker = kc_job_contains_wrecker(engine, target) ||
        kc_pending_assignment_has_wrecker_for_suit(engine, target) ||
        (planned_wrecker && planned_wrecker[target]);
    int32_t revealed_value = engine->has_revealed_job[target] ?
        engine->revealed_jobs[target].value : 0;
    int32_t risk = kc_benchmark_plot_risk_count(engine, player_id, target);

    if (kc_card_is_wrecker(card)) {
        int32_t score = 0;
        score -= current_work * 10;
        score -= revealed_value * 45;
        score -= risk * 25;
        if (engine->claimed_jobs[target]) {
            score -= 80;
        }
        if (has_wrecker) {
            score += 120;
        }
        return score;
    }

    int32_t next_work = current_work + card_work;
    int32_t score = card_work;
    if (engine->claimed_jobs[target]) {
        score -= 120;
    }
    if (has_wrecker) {
        score -= 240;
    }
    score += risk * 20;
    score += revealed_value * 25;
    if (current_work < KC_WORK_THRESHOLD && next_work >= KC_WORK_THRESHOLD) {
        score += 420 - (next_work - KC_WORK_THRESHOLD) * 6;
        if (card_work >= 10) {
            score += 40;
        }
    } else if (next_work < KC_WORK_THRESHOLD) {
        score += next_work * 2;
        if (next_work >= 30) {
            score += 80;
        } else if (next_work >= 20) {
            score += 40;
        } else if (current_work < 10) {
            score -= 30;
        }
    } else {
        score += 30;
    }
    return score;
}

static int32_t kc_benchmark_concentrate_score(
    const KCEngine *engine,
    int32_t target,
    int32_t player_id,
    int32_t remaining_work,
    bool remaining_has_wrecker
) {
    if (!engine || !kc_valid_suit(target)) {
        return -100000;
    }
    int32_t current_work = engine->work_hours[target] +
        kc_pending_assignment_work_for_suit(engine, target);
    if (engine->claimed_jobs[target]) {
        return -200;
    }
    int32_t score = 0;
    int32_t new_work = current_work + remaining_work;
    if (new_work >= KC_WORK_THRESHOLD) {
        score += 2000 - (new_work - KC_WORK_THRESHOLD) * 20;
    } else {
        score += new_work * 10;
        if (new_work >= 30) {
            score += 300;
        } else if (new_work >= 20) {
            score += 150;
        }
    }
    score += kc_benchmark_plot_risk_count(engine, player_id, target) * 200;
    if (engine->has_revealed_job[target]) {
        score += engine->revealed_jobs[target].value * 80;
    }
    if (remaining_has_wrecker || kc_job_contains_wrecker(engine, target) ||
        kc_pending_assignment_has_wrecker_for_suit(engine, target)) {
        score -= 1800 + current_work * 20;
    }
    return score;
}

static void kc_benchmark_assignment_plan(const KCEngine *engine, int32_t player_id, int32_t targets[KC_PLAYER_COUNT]) {
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        targets[i] = KC_NO_SUIT;
    }
    if (!engine || !kc_valid_player_id(player_id)) {
        return;
    }
    int32_t legal_suits[KC_SUIT_COUNT];
    int32_t legal_count = 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (kc_assignment_target_legal(engine, suit)) {
            legal_suits[legal_count++] = suit;
        }
    }
    if (legal_count <= 0) {
        return;
    }
    int32_t remaining_work = 0;
    bool remaining_has_wrecker = false;
    int32_t remaining_indices[KC_PLAYER_COUNT];
    int32_t remaining_count = 0;
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (engine->pending_assignment_targets[i] >= 0) {
            targets[i] = engine->pending_assignment_targets[i];
            continue;
        }
        remaining_indices[remaining_count++] = i;
        remaining_work += kc_work_value(engine, engine->last_trick[i].card);
        if (kc_card_is_wrecker(engine->last_trick[i].card)) {
            remaining_has_wrecker = true;
        }
    }
    if (remaining_count <= 0) {
        return;
    }

    int32_t best_concentrate_suit = legal_suits[0];
    int32_t best_concentrate_score = -1000000;
    for (int32_t i = 0; i < legal_count; i++) {
        int32_t suit = legal_suits[i];
        int32_t score = kc_benchmark_concentrate_score(
            engine,
            suit,
            player_id,
            remaining_work,
            remaining_has_wrecker
        );
        if (score > best_concentrate_score ||
            (score == best_concentrate_score && suit < best_concentrate_suit)) {
            best_concentrate_score = score;
            best_concentrate_suit = suit;
        }
    }

    int32_t split_targets[KC_PLAYER_COUNT];
    int32_t split_added_work[KC_SUIT_COUNT] = {0};
    bool split_planned_wrecker[KC_SUIT_COUNT] = {0};
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        split_targets[i] = KC_NO_SUIT;
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        int32_t pending = engine->pending_assignment_targets[i];
        if (pending >= 0 && pending < KC_SUIT_COUNT) {
            split_added_work[pending] += kc_work_value(engine, engine->last_trick[i].card);
            if (kc_card_is_wrecker(engine->last_trick[i].card)) {
                split_planned_wrecker[pending] = true;
            }
        }
    }
    for (int32_t sorted = 0; sorted < remaining_count; sorted++) {
        int32_t best_index = -1;
        for (int32_t i = 0; i < remaining_count; i++) {
            int32_t index = remaining_indices[i];
            if (split_targets[index] >= 0) {
                continue;
            }
            if (best_index < 0 ||
                kc_work_value(engine, engine->last_trick[index].card) >
                    kc_work_value(engine, engine->last_trick[best_index].card)) {
                best_index = index;
            }
        }
        if (best_index < 0) {
            break;
        }
        KCCard card = engine->last_trick[best_index].card;
        int32_t best_suit = legal_suits[0];
        int32_t best_score = -1000000;
        for (int32_t i = 0; i < legal_count; i++) {
            int32_t suit = legal_suits[i];
            int32_t score = kc_benchmark_assignment_card_score(
                engine,
                card,
                suit,
                player_id,
                split_added_work,
                split_planned_wrecker
            );
            if (score > best_score ||
                (score == best_score && suit < best_suit)) {
                best_score = score;
                best_suit = suit;
            }
        }
        split_targets[best_index] = best_suit;
        split_added_work[best_suit] += kc_work_value(engine, card);
        if (kc_card_is_wrecker(card)) {
            split_planned_wrecker[best_suit] = true;
        }
    }

    int32_t split_score = 0;
    for (int32_t i = 0; i < remaining_count; i++) {
        int32_t index = remaining_indices[i];
        int32_t suit = split_targets[index];
        if (suit >= 0) {
            split_score += kc_benchmark_assignment_card_score(
                engine,
                engine->last_trick[index].card,
                suit,
                player_id,
                NULL,
                NULL
            );
        }
    }
    if (best_concentrate_score >= split_score) {
        for (int32_t i = 0; i < remaining_count; i++) {
            targets[remaining_indices[i]] = best_concentrate_suit;
        }
    } else {
        for (int32_t i = 0; i < remaining_count; i++) {
            targets[remaining_indices[i]] = split_targets[remaining_indices[i]];
        }
    }
}

static int32_t kc_benchmark_assignment_score(const KCEngine *engine, KCAction action) {
    if (!engine || !kc_valid_suit(action.target_suit)) {
        return 0;
    }
    int32_t planned_targets[KC_PLAYER_COUNT];
    kc_benchmark_assignment_plan(engine, action.player_id, planned_targets);
    int32_t matched_index = -1;
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (engine->pending_assignment_targets[i] < 0 &&
            kc_card_equal(engine->last_trick[i].card, action.card)) {
            matched_index = i;
            break;
        }
    }
    int32_t score = kc_benchmark_assignment_card_score(
        engine,
        action.card,
        action.target_suit,
        action.player_id,
        NULL,
        NULL
    );
    if (matched_index >= 0 && planned_targets[matched_index] == action.target_suit) {
        score += 5000;
    }
    return score;
}

static int32_t kc_benchmark_action_score(const KCEngine *engine, KCAction action) {
    switch (action.kind) {
    case KC_ACTION_SET_TRUMP:
        return 1000 + kc_benchmark_trump_score(engine, action);
    case KC_ACTION_PLAY_CARD:
        return 1000 + kc_benchmark_play_score(engine, action);
    case KC_ACTION_ASSIGN:
        return 1000 + kc_benchmark_assignment_score(engine, action);
    case KC_ACTION_CONFIRM_SWAP:
    case KC_ACTION_SUBMIT_ASSIGNMENTS:
    case KC_ACTION_CONTINUE_AFTER_REQUISITION:
        return 900;
    default:
        return 0;
    }
}

bool kc_choose_benchmark_action(const KCEngine *engine, const KCAction *actions, int32_t count, KCAction *selected) {
    bool has_swap = false;
    KCAction best_swap = {0};
    int32_t best_swap_score = 0;
    for (int32_t i = 0; i < count; i++) {
        KCAction action = actions[i];
        if (action.kind != KC_ACTION_SWAP) {
            continue;
        }
        int32_t score = kc_benchmark_swap_score(engine, action);
        if (!has_swap ||
            score > best_swap_score ||
            (score == best_swap_score && kc_action_less(action, best_swap))) {
            has_swap = true;
            best_swap = action;
            best_swap_score = score;
        }
    }
    if (has_swap && best_swap_score > 50) {
        *selected = best_swap;
        return true;
    }

    for (int32_t i = 0; i < count; i++) {
        if (actions[i].kind == KC_ACTION_SUBMIT_ASSIGNMENTS) {
            *selected = actions[i];
            return true;
        }
    }
    for (int32_t i = 0; i < count; i++) {
        if (actions[i].kind == KC_ACTION_CONFIRM_SWAP) {
            *selected = actions[i];
            return true;
        }
    }
    for (int32_t i = 0; i < count; i++) {
        if (actions[i].kind == KC_ACTION_CONTINUE_AFTER_REQUISITION) {
            *selected = actions[i];
            return true;
        }
    }
    if (count <= 0) {
        return false;
    }
    KCAction best = actions[0];
    int32_t best_score = kc_benchmark_action_score(engine, best);
    for (int32_t i = 1; i < count; i++) {
        int32_t score = kc_benchmark_action_score(engine, actions[i]);
        if (score > best_score ||
            (score == best_score && kc_action_less(actions[i], best))) {
            best = actions[i];
            best_score = score;
        }
    }
    *selected = best;
    return true;
}

bool kc_heuristic_policy_action(const KCEngine *engine, KCAction *selected) {
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    return kc_choose_benchmark_action(engine, actions, count, selected);
}

bool kc_engine_heuristic_policy_action(const KCEngine *engine, KCAction *selected) {
    return kc_heuristic_policy_action(engine, selected);
}

static double kc_card_value_feature(KCCard card) {
    return kc_card_valid(card) ? (double)card.value / (double)KC_POLICY_CARD_VALUE_SCALE : 0.0;
}

static double kc_raw_card_value_feature(int32_t value) {
    return value > 0 ? (double)value / (double)KC_POLICY_CARD_VALUE_SCALE : 0.0;
}

double kc_uniform_from_state(uint64_t *state) {
    if (*state == 0) {
        *state = 1;
    }
    *state = *state * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(*state >> 11) / (double)(1ULL << 53);
}

int32_t kc_policy_parameter_count(KCPolicyModelBuffer model) {
    int32_t head_count = model.head_count > 1 ? model.head_count : 1;
    int32_t layer_count = model.layer_count > 0 ? model.layer_count : 1;
    if (layer_count > KC_MAX_POLICY_HIDDEN_LAYERS) {
        return 0;
    }
    int32_t total = 0;
    for (int32_t layer = 0; layer < layer_count; layer++) {
        int32_t input_size = layer == 0 ? model.input_size : model.layer_sizes[layer - 1];
        int32_t output_size = model.layer_count > 0 ? model.layer_sizes[layer] : model.hidden_size;
        total += input_size * output_size + output_size;
    }
    int32_t last_size = model.layer_count > 0 ? model.layer_sizes[layer_count - 1] : model.hidden_size;
    return total + last_size * head_count + head_count;
}

int32_t kc_policy_activation_count(KCPolicyModelBuffer model) {
    if (model.layer_count <= 0) {
        return model.hidden_size;
    }
    if (model.layer_count > KC_MAX_POLICY_HIDDEN_LAYERS) {
        return 0;
    }
    int32_t total = 0;
    for (int32_t layer = 0; layer < model.layer_count; layer++) {
        total += model.layer_sizes[layer];
    }
    return total;
}

static bool kc_policy_uses_layer_stack(KCPolicyModelBuffer model) {
    return model.layer_count > 0 && model.output_weights;
}

int32_t kc_policy_layer_count(KCPolicyModelBuffer model) {
    return kc_policy_uses_layer_stack(model) ? model.layer_count : 1;
}

int32_t kc_policy_layer_size(KCPolicyModelBuffer model, int32_t layer) {
    return kc_policy_uses_layer_stack(model) ? model.layer_sizes[layer] : model.hidden_size;
}

int32_t kc_policy_layer_input_size(KCPolicyModelBuffer model, int32_t layer) {
    return layer == 0 ? model.input_size : kc_policy_layer_size(model, layer - 1);
}

double *kc_policy_layer_weights(KCPolicyModelBuffer model, int32_t layer) {
    return kc_policy_uses_layer_stack(model) ? model.layer_weights[layer] : model.w1;
}

double *kc_policy_layer_biases(KCPolicyModelBuffer model, int32_t layer) {
    return kc_policy_uses_layer_stack(model) ? model.layer_biases[layer] : model.b1;
}

double *kc_policy_output_weights(KCPolicyModelBuffer model) {
    return kc_policy_uses_layer_stack(model) ? model.output_weights : model.w2;
}

int32_t kc_policy_layer_activation_offset(KCPolicyModelBuffer model, int32_t layer) {
    int32_t offset = 0;
    for (int32_t index = 0; index < layer; index++) {
        offset += kc_policy_layer_size(model, index);
    }
    return offset;
}

int32_t kc_policy_output_offset(KCPolicyModelBuffer model) {
    int32_t offset = 0;
    int32_t layer_count = kc_policy_layer_count(model);
    for (int32_t layer = 0; layer < layer_count; layer++) {
        int32_t input_size = kc_policy_layer_input_size(model, layer);
        int32_t output_size = kc_policy_layer_size(model, layer);
        offset += input_size * output_size + output_size;
    }
    return offset;
}

static void kc_add_policy_feature(KCPolicyActionCandidate *candidate, int32_t index, double value) {
    if (value == 0) {
        return;
    }
    if (candidate->feature_count >= 256) {
        return;
    }
    int32_t write_index = candidate->feature_count++;
    candidate->feature_indices[write_index] = index;
    candidate->feature_values[write_index] = value;
}

static void kc_add_policy_one_hot(KCPolicyActionCandidate *candidate, int32_t base_index, int32_t selected, int32_t count) {
    if (selected >= 0 && selected < count) {
        kc_add_policy_feature(candidate, base_index + selected, 1.0);
    }
}

int32_t kc_total_medals_for_player(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    return engine->players[player_id].plot_medals + engine->players[player_id].medals;
}

int32_t kc_total_medals(const KCEngine *engine, int32_t player_id) {
    return kc_total_medals_for_player(engine, player_id);
}

bool kc_player_beats_player(const int32_t *scores, const int32_t *medals, int32_t lhs, int32_t rhs) {
    if (scores[lhs] != scores[rhs]) {
        return scores[lhs] > scores[rhs];
    }
    if (medals[lhs] != medals[rhs]) {
        return medals[lhs] > medals[rhs];
    }
    return lhs > rhs;
}

double kc_model_score_cached(KCPolicyModelBuffer model, const KCPolicyActionCandidate *candidate, double *hidden_values) {
    int32_t head_count = model.head_count > 1 ? model.head_count : 1;
    int32_t action_head = candidate->action_head >= 0 ? candidate->action_head : 0;
    int32_t player_id = candidate->action.player_id >= 0 && candidate->action.player_id < KC_PLAYER_COUNT ? candidate->action.player_id : 0;
    int32_t head = head_count == KC_PLAYER_COUNT * KC_SUIT_COUNT
        ? player_id * KC_SUIT_COUNT + (action_head % KC_SUIT_COUNT)
        : (action_head < head_count ? action_head : 0);
    int32_t layer_count = kc_policy_layer_count(model);
    for (int32_t layer = 0; layer < layer_count; layer++) {
        int32_t input_size = kc_policy_layer_input_size(model, layer);
        int32_t output_size = kc_policy_layer_size(model, layer);
        double *weights = kc_policy_layer_weights(model, layer);
        double *biases = kc_policy_layer_biases(model, layer);
        double *output = hidden_values + kc_policy_layer_activation_offset(model, layer);
        double *previous = layer == 0 ? NULL : hidden_values + kc_policy_layer_activation_offset(model, layer - 1);

        for (int32_t row = 0; row < output_size; row++) {
            double value = biases[row];
            int32_t offset = row * input_size;
            if (layer == 0) {
                for (int32_t feature_index = 0; feature_index < candidate->feature_count; feature_index++) {
                    int32_t column = candidate->feature_indices[feature_index];
                    if (column < 0 || column >= input_size) {
                        continue;
                    }
                    value += weights[offset + column] * candidate->feature_values[feature_index];
                }
            } else {
                for (int32_t column = 0; column < input_size; column++) {
                    value += weights[offset + column] * previous[column];
                }
            }
            output[row] = value > 0 ? value : 0;
        }
    }

    double output = model.b2s ? model.b2s[head] : *model.b2;
    int32_t last_size = kc_policy_layer_size(model, layer_count - 1);
    double *last_hidden = hidden_values + kc_policy_layer_activation_offset(model, layer_count - 1);
    double *output_weights = kc_policy_output_weights(model);
    for (int32_t row = 0; row < last_size; row++) {
        output += output_weights[head * last_size + row] * last_hidden[row];
    }
    return output;
}

void kc_add_cached_score_gradient(KCPolicyModelBuffer model, const KCPolicyActionCandidate *candidate, double scale, double *gradient) {
    int32_t head_count = model.head_count > 1 ? model.head_count : 1;
    int32_t action_head = candidate->action_head >= 0 ? candidate->action_head : 0;
    int32_t player_id = candidate->action.player_id >= 0 && candidate->action.player_id < KC_PLAYER_COUNT ? candidate->action.player_id : 0;
    int32_t head = head_count == KC_PLAYER_COUNT * KC_SUIT_COUNT
        ? player_id * KC_SUIT_COUNT + (action_head % KC_SUIT_COUNT)
        : (action_head < head_count ? action_head : 0);
    int32_t layer_count = kc_policy_layer_count(model);
    int32_t activation_count = kc_policy_activation_count(model);
    if (activation_count > KC_MAX_POLICY_ACTIVATIONS) {
        return;
    }

    double upstream[KC_MAX_POLICY_ACTIVATIONS];
    memset(upstream, 0, (size_t)activation_count * sizeof(double));
    int32_t output_offset = kc_policy_output_offset(model);
    int32_t last_layer = layer_count - 1;
    int32_t last_size = kc_policy_layer_size(model, last_layer);
    int32_t last_activation_offset = kc_policy_layer_activation_offset(model, last_layer);
    double *last_hidden = candidate->hidden + last_activation_offset;
    double *output_weights = kc_policy_output_weights(model);
    int32_t b2_offset = output_offset + last_size * head_count;
    gradient[b2_offset + head] += scale;

    for (int32_t row = 0; row < last_size; row++) {
        gradient[output_offset + head * last_size + row] += scale * last_hidden[row];
        upstream[last_activation_offset + row] += output_weights[head * last_size + row] * scale;
    }

    for (int32_t layer = layer_count - 1; layer >= 0; layer--) {
        int32_t input_size = kc_policy_layer_input_size(model, layer);
        int32_t output_size = kc_policy_layer_size(model, layer);
        int32_t activation_offset = kc_policy_layer_activation_offset(model, layer);
        int32_t previous_activation_offset = layer == 0 ? 0 : kc_policy_layer_activation_offset(model, layer - 1);
        int32_t param_offset = 0;
        for (int32_t previous_layer = 0; previous_layer < layer; previous_layer++) {
            int32_t previous_input = kc_policy_layer_input_size(model, previous_layer);
            int32_t previous_output = kc_policy_layer_size(model, previous_layer);
            param_offset += previous_input * previous_output + previous_output;
        }
        int32_t bias_offset = param_offset + input_size * output_size;
        double *weights = kc_policy_layer_weights(model, layer);
        double *hidden = candidate->hidden + activation_offset;
        double *previous_hidden = layer == 0 ? NULL : candidate->hidden + previous_activation_offset;

        for (int32_t row = 0; row < output_size; row++) {
            if (hidden[row] <= 0) {
                continue;
            }
            double delta = upstream[activation_offset + row];
            int32_t row_offset = row * input_size;
            gradient[bias_offset + row] += delta;
            if (layer == 0) {
                for (int32_t feature_index = 0; feature_index < candidate->feature_count; feature_index++) {
                    int32_t column = candidate->feature_indices[feature_index];
                    if (column < 0 || column >= input_size) {
                        continue;
                    }
                    gradient[param_offset + row_offset + column] += delta * candidate->feature_values[feature_index];
                }
            } else {
                for (int32_t column = 0; column < input_size; column++) {
                    gradient[param_offset + row_offset + column] += delta * previous_hidden[column];
                    upstream[previous_activation_offset + column] += delta * weights[row_offset + column];
                }
            }
        }
    }
}

bool kc_would_currently_win(const KCEngine *engine, KCCard card) {
    if (!kc_card_valid(card) || engine->current_trick_count <= 0) {
        return false;
    }
    int32_t lead_suit = kc_lead_suit(engine);
    bool has_trump = engine->trump >= 0 && kc_card_matches_suit(card, engine->trump);
    int32_t winning_suit = lead_suit;
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        if (kc_card_matches_suit(engine->current_trick[i].card, engine->trump)) {
            has_trump = true;
            break;
        }
    }
    if (has_trump) {
        winning_suit = engine->trump;
    }
    if (winning_suit != KC_NO_SUIT && !kc_card_matches_suit(card, winning_suit)) {
        return false;
    }
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        KCCard play = engine->current_trick[i].card;
        if ((winning_suit == KC_NO_SUIT || kc_card_matches_suit(play, winning_suit)) &&
            play.value > card.value) {
            return false;
        }
    }
    return true;
}

int32_t kc_revealed_plot_count_for_player(const KCPlayer *player, int32_t suit) {
    int32_t count = 0;
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        if (suit < 0 || kc_card_matches_suit(player->plot_revealed.cards[i], suit)) count++;
    }
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->revealed_count; i++) {
            if (suit < 0 || kc_card_matches_suit(stack->revealed[i], suit)) count++;
        }
    }
    return count;
}

int32_t kc_hidden_plot_count_for_player(const KCPlayer *player, int32_t suit) {
    int32_t count = 0;
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        if (suit < 0 || kc_card_matches_suit(player->plot_hidden.cards[i], suit)) count++;
    }
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->hidden_count; i++) {
            if (suit < 0 || kc_card_matches_suit(stack->hidden[i], suit)) count++;
        }
    }
    return count;
}

int32_t kc_known_score_for_player(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    const KCPlayer *player = &engine->players[player_id];
    int32_t score = kc_visible_score(engine, player_id);
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        score += player->plot_hidden.cards[i].value;
    }
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->hidden_count; i++) {
            score += stack->hidden[i].value;
        }
    }
    return score;
}

static int32_t kc_dense_action_id(int32_t value, int32_t offset, int32_t count);

static KCObjectToken *kc_object_append(KCObjectToken *tokens, int32_t max_tokens, int32_t *count, int32_t type, int32_t owner, int32_t zone, int32_t suit, int32_t value, int32_t index) {
    if (!tokens || !count || *count >= max_tokens) {
        return NULL;
    }
    KCObjectToken *token = &tokens[*count];
    memset(token, 0, sizeof(*token));
    token->type = type;
    token->owner = owner;
    token->zone = zone;
    token->suit = suit;
    token->value = value;
    token->index = index;
    (*count)++;
    return token;
}

static void kc_object_append_card(KCObjectToken *tokens, int32_t max_tokens, int32_t *count, KCCard card, int32_t owner, int32_t zone, int32_t index, bool reveal, bool hidden) {
    if (!kc_card_valid(card)) {
        return;
    }
    int32_t exported_zone = reveal ? zone : KC_OBJECT_ZONE_UNKNOWN_HIDDEN;
    int32_t exported_suit = reveal ? card.suit : -1;
    int32_t exported_value = reveal ? card.value : 0;
    KCObjectToken *token = kc_object_append(tokens, max_tokens, count, KC_OBJECT_CARD, owner, exported_zone, exported_suit, exported_value, index);
    if (!token) {
        return;
    }
    token->scalars[0] = reveal ? 1.0 : 0.0;
    token->scalars[1] = hidden ? 1.0 : 0.0;
    token->scalars[2] = reveal ? kc_card_value_feature(card) : 0.0;
    token->scalars[3] = owner >= 0 ? (double)owner / 3.0 : 0.0;
    token->scalars[4] = reveal && kc_card_is_wrecker(card) ? 1.0 : 0.0;
}

static void kc_object_append_card_list(KCObjectToken *tokens, int32_t max_tokens, int32_t *count, const KCCardList *list, int32_t owner, int32_t zone, bool reveal, bool hidden) {
    for (int32_t index = 0; list && index < list->count && *count < max_tokens; index++) {
        kc_object_append_card(tokens, max_tokens, count, list->cards[index], owner, zone, index, reveal, hidden);
    }
}

int32_t kc_engine_object_tokens(const KCEngine *engine, int32_t perspective_player, KCObjectToken *tokens, int32_t max_tokens) {
    if (!engine || !tokens || max_tokens <= 0) {
        return 0;
    }
    if (perspective_player < 0 || perspective_player >= KC_PLAYER_COUNT) {
        perspective_player = engine->current_player >= 0 && engine->current_player < KC_PLAYER_COUNT ? engine->current_player : 0;
    }

    int32_t count = 0;
    KCObjectToken *global = kc_object_append(tokens, max_tokens, &count, KC_OBJECT_GLOBAL, perspective_player, engine->phase, engine->trump, engine->year, engine->current_player);
    if (global) {
        global->scalars[0] = (double)engine->year / 5.0;
        global->scalars[1] = (double)engine->phase / 5.0;
        global->scalars[2] = engine->current_player >= 0 ? (double)engine->current_player / 3.0 : 0.0;
        global->scalars[3] = engine->lead >= 0 ? (double)engine->lead / 3.0 : 0.0;
        global->scalars[4] = engine->trump_selector >= 0 ? (double)engine->trump_selector / 3.0 : 0.0;
        global->scalars[5] = (double)engine->trick_count / 4.0;
        global->scalars[6] = (double)engine->current_trick_count / 4.0;
        global->scalars[7] = engine->is_famine ? 1.0 : 0.0;
    }

    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT && count < max_tokens; player_id++) {
        const KCPlayer *player = &engine->players[player_id];
        KCObjectToken *token = kc_object_append(
            tokens,
            max_tokens,
            &count,
            KC_OBJECT_PLAYER,
            player_id,
            engine->controllers.seats[player_id],
            -1,
            player->has_won_trick_this_year ? 1 : 0,
            (player_id - perspective_player + KC_PLAYER_COUNT) % KC_PLAYER_COUNT
        );
        if (!token) {
            continue;
        }
        token->scalars[0] = (double)player->hand.count / 5.0;
        token->scalars[1] = (double)kc_revealed_plot_count_for_player(player, -1) / 16.0;
        token->scalars[2] = (double)kc_hidden_plot_count_for_player(player, -1) / 16.0;
        token->scalars[3] = (double)player->medals / 20.0;
        token->scalars[4] = (double)kc_total_medals_for_player(engine, player_id) / 20.0;
        token->scalars[5] = (double)kc_visible_score(engine, player_id) / 100.0;
        token->scalars[6] = (double)(player_id == perspective_player ? kc_known_score_for_player(engine, player_id) : kc_visible_score(engine, player_id)) / 100.0;
        token->scalars[7] = player->brigade_leader ? 1.0 : 0.0;
    }

    for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_tokens; suit++) {
        KCObjectToken *token = kc_object_append(
            tokens,
            max_tokens,
            &count,
            KC_OBJECT_JOB,
            -1,
            engine->claimed_jobs[suit] ? 1 : 0,
            suit,
            engine->has_revealed_job[suit] ? engine->revealed_jobs[suit].value : 0,
            suit
        );
        if (!token) {
            continue;
        }
        token->scalars[0] = (double)engine->work_hours[suit] / 40.0;
        token->scalars[1] = (double)(engine->work_hours[suit] < 40 ? 40 - engine->work_hours[suit] : 0) / 40.0;
        token->scalars[2] = engine->has_revealed_job[suit] ? (double)engine->revealed_jobs[suit].value / 5.0 : 0.0;
        token->scalars[3] = engine->claimed_jobs[suit] ? 1.0 : 0.0;
        token->scalars[4] = (double)engine->job_piles[suit].count / 16.0;
        token->scalars[5] = (double)engine->job_buckets[suit].count / 16.0;
        token->scalars[6] = (double)engine->accumulated_job_cards[suit].count / 16.0;
        token->scalars[7] = engine->has_revealed_job[suit] ? 1.0 : 0.0;
    }

    const KCPlayer *perspective = &engine->players[perspective_player];
    int32_t opponent_hidden_total = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (player_id == perspective_player) {
            continue;
        }
        opponent_hidden_total += kc_hidden_plot_count_for_player(&engine->players[player_id], -1);
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_tokens; suit++) {
        int32_t own_hand_count = 0;
        for (int32_t index = 0; index < perspective->hand.count; index++) {
            KCCard card = perspective->hand.cards[index];
            if (!kc_card_matches_suit(card, suit)) {
                continue;
            }
            own_hand_count++;
        }
        int32_t visible_plot_count = 0;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            visible_plot_count += kc_revealed_plot_count_for_player(&engine->players[player_id], suit);
        }
        KCObjectToken *token = kc_object_append(
            tokens,
            max_tokens,
            &count,
            KC_OBJECT_BELIEF,
            perspective_player,
            KC_OBJECT_ZONE_UNKNOWN_HIDDEN,
            suit,
            engine->has_revealed_job[suit] ? engine->revealed_jobs[suit].value : 0,
            suit
        );
        if (!token) {
            continue;
        }
        token->scalars[0] = (double)engine->work_hours[suit] / 40.0;
        token->scalars[1] = (double)(engine->work_hours[suit] < 40 ? 40 - engine->work_hours[suit] : 0) / 40.0;
        token->scalars[2] = engine->has_revealed_job[suit] ? (double)engine->revealed_jobs[suit].value / 5.0 : 0.0;
        token->scalars[3] = engine->claimed_jobs[suit] ? 1.0 : 0.0;
        token->scalars[4] = (double)own_hand_count / 5.0;
        token->scalars[5] = (double)kc_hidden_plot_count_for_player(perspective, suit) / 8.0;
        token->scalars[6] = (double)visible_plot_count / 32.0;
        token->scalars[7] = (double)opponent_hidden_total / 32.0;
    }

    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT && count < max_tokens; player_id++) {
        const KCPlayer *player = &engine->players[player_id];
        bool own = player_id == perspective_player;
        kc_object_append_card_list(tokens, max_tokens, &count, &player->hand, player_id, KC_OBJECT_ZONE_HAND, own, true);
        kc_object_append_card_list(tokens, max_tokens, &count, &player->plot_revealed, player_id, KC_OBJECT_ZONE_PLOT_REVEALED, true, false);
        kc_object_append_card_list(tokens, max_tokens, &count, &player->plot_hidden, player_id, KC_OBJECT_ZONE_PLOT_HIDDEN, own, true);
        for (int32_t stack_index = 0; stack_index < player->stack_count && count < max_tokens; stack_index++) {
            const KCPlotStack *stack = &player->stacks[stack_index];
            for (int32_t index = 0; index < stack->revealed_count && count < max_tokens; index++) {
                kc_object_append_card(tokens, max_tokens, &count, stack->revealed[index], player_id, KC_OBJECT_ZONE_STACK_REVEALED, stack_index * KC_MAX_CARDS + index, true, false);
            }
            for (int32_t index = 0; index < stack->hidden_count && count < max_tokens; index++) {
                kc_object_append_card(tokens, max_tokens, &count, stack->hidden[index], player_id, KC_OBJECT_ZONE_STACK_HIDDEN, stack_index * KC_MAX_CARDS + index, own, true);
            }
        }
    }

    for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_tokens; suit++) {
        if (engine->has_revealed_job[suit]) {
            kc_object_append_card(tokens, max_tokens, &count, engine->revealed_jobs[suit], -1, KC_OBJECT_ZONE_REVEALED_JOB, suit, true, false);
        }
        kc_object_append_card_list(tokens, max_tokens, &count, &engine->job_buckets[suit], -1, KC_OBJECT_ZONE_JOB_BUCKET, true, false);
        kc_object_append_card_list(tokens, max_tokens, &count, &engine->accumulated_job_cards[suit], -1, KC_OBJECT_ZONE_ACCUMULATED_JOB, true, false);
    }

    for (int32_t index = 0; index < engine->current_trick_count && count < max_tokens; index++) {
        kc_object_append_card(tokens, max_tokens, &count, engine->current_trick[index].card, engine->current_trick[index].player_id, KC_OBJECT_ZONE_CURRENT_TRICK, index, true, false);
    }
    for (int32_t index = 0; index < engine->last_trick_count && count < max_tokens; index++) {
        kc_object_append_card(tokens, max_tokens, &count, engine->last_trick[index].card, engine->last_trick[index].player_id, KC_OBJECT_ZONE_LAST_TRICK, index, true, false);
        int32_t target_suit = engine->pending_assignment_targets[index];
        if (engine->phase == KC_PHASE_ASSIGNMENT && target_suit >= 0 && count < max_tokens) {
            KCCard card = engine->last_trick[index].card;
            KCObjectToken *assignment = kc_object_append(
                tokens,
                max_tokens,
                &count,
                KC_OBJECT_ASSIGNMENT,
                engine->last_trick[index].player_id,
                KC_OBJECT_ZONE_PENDING_ASSIGNMENT,
                target_suit,
                card.value,
                index
            );
            if (assignment) {
                assignment->scalars[0] = 1.0;
                assignment->scalars[1] = (double)target_suit / 3.0;
                assignment->scalars[2] = kc_card_is_wrecker(card) ? 1.0 : (double)card.suit / 3.0;
                assignment->scalars[3] = kc_card_value_feature(card);
                assignment->scalars[4] = (double)(index + 1) / 4.0;
                assignment->scalars[5] = kc_card_is_wrecker(card) ? 1.0 : 0.0;
            }
        }
    }
    for (int32_t year = 0; year <= KC_MAX_YEARS && count < max_tokens; year++) {
        const KCCardList *exiled = &engine->exiled[year];
        for (int32_t index = 0; index < exiled->count && count < max_tokens; index++) {
            kc_object_append_card(tokens, max_tokens, &count, exiled->cards[index], -1, KC_OBJECT_ZONE_EXILED, year * KC_MAX_CARDS + index, true, false);
        }
    }
    kc_object_append_card_list(tokens, max_tokens, &count, &engine->drunkard_replacements, -1, KC_OBJECT_ZONE_DRUNKARD_REPLACEMENT, true, false);
    return count;
}

int32_t kc_engine_object_token_dense_features(const KCEngine *engine, int32_t perspective_player, KCDenseObjectTokens output) {
    if (!engine || output.max_tokens <= 0) {
        return 0;
    }
    int32_t capacity = output.max_tokens < KC_MAX_OBJECT_TOKENS ? output.max_tokens : KC_MAX_OBJECT_TOKENS;
    KCObjectToken tokens[KC_MAX_OBJECT_TOKENS];
    int32_t count = kc_engine_object_tokens(engine, perspective_player, tokens, capacity);
    for (int32_t row = 0; row < count; row++) {
        KCObjectToken *token = &tokens[row];
        if (output.type_ids) output.type_ids[row] = token->type;
        if (output.owner_ids) output.owner_ids[row] = kc_dense_action_id(token->owner, 1, 6);
        if (output.zone_ids) output.zone_ids[row] = kc_dense_action_id(token->zone, 0, 32);
        if (output.suit_ids) output.suit_ids[row] = kc_dense_action_id(token->suit, 1, 6);
        if (output.value_ids) output.value_ids[row] = kc_dense_action_id(token->value, 0, 16);
        if (output.index_ids) output.index_ids[row] = kc_dense_action_id(token->index, 0, 64);
        if (output.scalars) {
            for (int32_t scalar = 0; scalar < KC_OBJECT_SCALAR_COUNT; scalar++) {
                output.scalars[(size_t)row * KC_OBJECT_SCALAR_COUNT + scalar] = (float)token->scalars[scalar];
            }
        }
    }
    return count;
}

static void kc_add_trick_features(KCPolicyActionCandidate *candidate, int32_t base_index, const KCTrickPlay *plays, int32_t play_count) {
    for (int32_t slot = 0; slot < KC_PLAYER_COUNT; slot++) {
        int32_t offset = base_index + slot * 7;
        if (slot >= play_count) {
            continue;
        }
        KCCard card = plays[slot].card;
        kc_add_policy_feature(candidate, offset, 1.0);
        kc_add_policy_feature(candidate, offset + 1, (double)plays[slot].player_id / 3.0);
        kc_add_policy_one_hot(candidate, offset + 2, card.suit, KC_SUIT_COUNT);
        kc_add_policy_feature(candidate, offset + 6, kc_card_value_feature(card));
    }
}

static void kc_state_add_feature(float *features, int32_t feature_count, int32_t index, double value) {
    if (!features || index < 0 || index >= feature_count) {
        return;
    }
    features[index] = (float)value;
}

static void kc_state_add_one_hot(float *features, int32_t feature_count, int32_t base, int32_t selected, int32_t count) {
    if (selected >= 0 && selected < count) {
        kc_state_add_feature(features, feature_count, base + selected, 1.0);
    }
}

static void kc_state_add_trick_features(float *features, int32_t feature_count, int32_t base_index, const KCTrickPlay *plays, int32_t play_count) {
    for (int32_t slot = 0; slot < KC_PLAYER_COUNT; slot++) {
        int32_t offset = base_index + slot * 7;
        if (slot >= play_count) {
            continue;
        }
        KCCard card = plays[slot].card;
        kc_state_add_feature(features, feature_count, offset, 1.0);
        kc_state_add_feature(features, feature_count, offset + 1, (double)plays[slot].player_id / 3.0);
        kc_state_add_one_hot(features, feature_count, offset + 2, card.suit, KC_SUIT_COUNT);
        kc_state_add_feature(features, feature_count, offset + 6, kc_card_value_feature(card));
    }
}

int32_t kc_engine_state_features(const KCEngine *engine, int32_t perspective_player, float *features, int32_t feature_count) {
    if (!engine || !features || feature_count <= 0 || perspective_player < 0 || perspective_player >= KC_PLAYER_COUNT) {
        return 0;
    }
    memset(features, 0, (size_t)feature_count * sizeof(float));
    int32_t limit = feature_count < KC_STATE_INPUT_SIZE ? feature_count : KC_STATE_INPUT_SIZE;

    const KCPlayer *player = &engine->players[perspective_player];
    int32_t own_visible = kc_visible_score(engine, perspective_player);
    int32_t own_known = kc_known_score_for_player(engine, perspective_player);
    int32_t best_opponent_visible = -1000000;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == perspective_player) continue;
        int32_t visible = kc_visible_score(engine, other);
        if (visible > best_opponent_visible) best_opponent_visible = visible;
    }
    if (best_opponent_visible < 0) best_opponent_visible = 0;

    kc_state_add_one_hot(features, limit, 0, engine->phase, 6);
    kc_state_add_one_hot(features, limit, 6, perspective_player, KC_PLAYER_COUNT);
    kc_state_add_one_hot(features, limit, 10, engine->trump, KC_SUIT_COUNT);
    kc_state_add_one_hot(features, limit, 14, engine->lead >= 0 ? (perspective_player - engine->lead + KC_PLAYER_COUNT) % KC_PLAYER_COUNT : -1, KC_PLAYER_COUNT);
    kc_state_add_one_hot(features, limit, 18, engine->trump_selector >= 0 ? (perspective_player - engine->trump_selector + KC_PLAYER_COUNT) % KC_PLAYER_COUNT : -1, KC_PLAYER_COUNT);
    kc_state_add_feature(features, limit, 22, (double)engine->year / 5.0);
    kc_state_add_feature(features, limit, 23, engine->is_famine ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 24, (double)engine->trick_count / 4.0);
    kc_state_add_feature(features, limit, 25, (double)engine->current_trick_count / 4.0);
    kc_state_add_feature(features, limit, 26, (double)engine->last_trick_count / 4.0);
    kc_state_add_one_hot(features, limit, 27, engine->last_winner >= 0 ? (perspective_player - engine->last_winner + KC_PLAYER_COUNT) % KC_PLAYER_COUNT : -1, KC_PLAYER_COUNT);
    kc_state_add_feature(features, limit, 31, (double)player->hand.count / 5.0);
    kc_state_add_feature(features, limit, 32, (double)kc_revealed_plot_count_for_player(player, -1) / 16.0);
    kc_state_add_feature(features, limit, 33, (double)kc_hidden_plot_count_for_player(player, -1) / 16.0);
    kc_state_add_feature(features, limit, 34, (double)kc_total_medals_for_player(engine, perspective_player) / 20.0);
    kc_state_add_feature(features, limit, 35, (double)own_visible / 100.0);
    kc_state_add_feature(features, limit, 36, (double)own_known / 100.0);
    kc_state_add_feature(features, limit, 37, (double)best_opponent_visible / 100.0);
    kc_state_add_feature(features, limit, 38, (double)(own_known - best_opponent_visible) / 100.0);
    kc_state_add_feature(features, limit, 39, player->has_won_trick_this_year ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 40, player->brigade_leader ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 41, engine->variants.nomenclature ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 42, engine->variants.allow_swap ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 43, engine->variants.northern_style ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 44, engine->variants.mice_variant ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 45, engine->variants.orden_nachalniku ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 46, engine->variants.medals_count ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 47, engine->variants.accumulate_jobs ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 48, engine->variants.hero_of_soviet_union ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 49, engine->variants.wrecker ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 50, engine->variants.final_year_trump ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 51, engine->variants.pass_cards ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 52, engine->variants.highest_cards_requisition ? 1.0 : 0.0);
    kc_state_add_feature(features, limit, 53, engine->variants.lotto_rewards ? 1.0 : 0.0);

    for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
        const KCPlayer *seat_player = &engine->players[seat];
        int32_t base = 56 + seat * 10;
        int32_t hand_max = 0;
        int32_t hand_min = 0;
        if (seat == perspective_player) {
            for (int32_t i = 0; i < seat_player->hand.count; i++) {
                int32_t value = seat_player->hand.cards[i].value;
                if (value > hand_max) hand_max = value;
                if (i == 0 || value < hand_min) hand_min = value;
            }
        }
        kc_state_add_feature(features, limit, base, (double)seat_player->hand.count / 5.0);
        kc_state_add_feature(features, limit, base + 1, (double)kc_revealed_plot_count_for_player(seat_player, -1) / 16.0);
        kc_state_add_feature(features, limit, base + 2, (double)kc_hidden_plot_count_for_player(seat_player, -1) / 16.0);
        kc_state_add_feature(features, limit, base + 3, (double)kc_total_medals_for_player(engine, seat) / 20.0);
        kc_state_add_feature(features, limit, base + 4, seat_player->has_won_trick_this_year ? 1.0 : 0.0);
        kc_state_add_feature(features, limit, base + 5, seat_player->brigade_leader ? 1.0 : 0.0);
        kc_state_add_feature(features, limit, base + 6, (double)kc_visible_score(engine, seat) / 100.0);
        kc_state_add_feature(features, limit, base + 7, (double)(seat == perspective_player ? kc_known_score_for_player(engine, seat) : kc_visible_score(engine, seat)) / 100.0);
        kc_state_add_feature(features, limit, base + 8, kc_raw_card_value_feature(hand_max));
        kc_state_add_feature(features, limit, base + 9, kc_raw_card_value_feature(hand_min));
    }

    int32_t public_hidden_total = 0;
    for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
        public_hidden_total += kc_hidden_plot_count_for_player(&engine->players[seat], -1);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t base = 96 + target * 12;
        int32_t own_hand_count = 0;
        int32_t own_hand_max = 0;
        int32_t own_hand_min = 0;
        int32_t all_revealed = 0;
        int32_t trick_suit_count = 0;
        for (int32_t i = 0; i < player->hand.count; i++) {
            if (!kc_card_matches_suit(player->hand.cards[i], target)) continue;
            int32_t value = player->hand.cards[i].value;
            own_hand_count++;
            if (value > own_hand_max) own_hand_max = value;
            if (own_hand_count == 1 || value < own_hand_min) own_hand_min = value;
        }
        for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
            all_revealed += kc_revealed_plot_count_for_player(&engine->players[seat], target);
        }
        for (int32_t i = 0; i < engine->current_trick_count; i++) {
            if (kc_card_matches_suit(engine->current_trick[i].card, target)) trick_suit_count++;
        }
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (kc_card_matches_suit(engine->last_trick[i].card, target)) trick_suit_count++;
        }
        kc_state_add_feature(features, limit, base, (double)engine->work_hours[target] / 40.0);
        kc_state_add_feature(features, limit, base + 1, (double)(engine->work_hours[target] < 40 ? 40 - engine->work_hours[target] : 0) / 40.0);
        kc_state_add_feature(features, limit, base + 2, engine->has_revealed_job[target] ? (double)engine->revealed_jobs[target].value / 5.0 : 0.0);
        kc_state_add_feature(features, limit, base + 3, engine->claimed_jobs[target] ? 1.0 : 0.0);
        kc_state_add_feature(features, limit, base + 4, (double)own_hand_count / 5.0);
        kc_state_add_feature(features, limit, base + 5, kc_raw_card_value_feature(own_hand_max));
        kc_state_add_feature(features, limit, base + 6, kc_raw_card_value_feature(own_hand_min));
        kc_state_add_feature(features, limit, base + 7, (double)kc_revealed_plot_count_for_player(player, target) / 8.0);
        kc_state_add_feature(features, limit, base + 8, (double)kc_hidden_plot_count_for_player(player, target) / 8.0);
        kc_state_add_feature(features, limit, base + 9, (double)all_revealed / 32.0);
        kc_state_add_feature(features, limit, base + 10, (double)public_hidden_total / 32.0);
        kc_state_add_feature(features, limit, base + 11, (double)trick_suit_count / 8.0);
    }

    kc_state_add_trick_features(features, limit, 144, engine->current_trick, engine->current_trick_count);
    kc_state_add_trick_features(features, limit, 172, engine->last_trick, engine->last_trick_count);
    return limit;
}

static void kc_policy_features(const KCEngine *engine, int32_t player_id, int32_t action_type, int32_t suit, KCCard card, KCCard hand_card, int32_t zone, double swap_delta, int32_t feature_size, KCPolicyActionCandidate *candidate) {
    const KCPlayer *player = &engine->players[player_id];
    int32_t lead_suit = kc_lead_suit(engine);
    int32_t trick_work = 0;
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        trick_work += kc_work_value(engine, engine->last_trick[i].card);
    }
    bool suit_is_crop = suit >= 0 && suit < KC_SUIT_COUNT;
    int32_t current_work = suit_is_crop ? engine->work_hours[suit] : 0;
    int32_t after_work = current_work + trick_work;
    int32_t suit_plot_count = 0;
    int32_t hidden_suit_count = 0;
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        if (kc_card_matches_suit(player->plot_hidden.cards[i], suit)) {
            suit_plot_count++;
            hidden_suit_count++;
        }
    }
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        if (kc_card_matches_suit(player->plot_revealed.cards[i], suit)) {
            suit_plot_count++;
        }
    }
    int32_t revealed_job = (suit_is_crop && engine->has_revealed_job[suit]) ? engine->revealed_jobs[suit].value : 0;

    candidate->feature_count = 0;
    candidate->action_head = action_type;
    if (feature_size == KC_POLICY_INPUT_SIZE) {
        int32_t own_visible = kc_visible_score(engine, player_id);
        int32_t own_known = kc_known_score_for_player(engine, player_id);
        int32_t best_opponent_visible = -1000000;
        for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
            if (other == player_id) continue;
            int32_t visible = kc_visible_score(engine, other);
            if (visible > best_opponent_visible) best_opponent_visible = visible;
        }

        kc_add_policy_one_hot(candidate, 0, action_type, KC_SUIT_COUNT);
        kc_add_policy_one_hot(candidate, 4, player_id, KC_PLAYER_COUNT);
        kc_add_policy_one_hot(candidate, 8, suit, KC_SUIT_COUNT);
        kc_add_policy_one_hot(candidate, 12, kc_card_valid(card) ? card.suit : -1, KC_SUIT_COUNT);
        kc_add_policy_feature(candidate, 16, kc_card_value_feature(card));
        kc_add_policy_feature(candidate, 17, kc_card_value_feature(hand_card));
        kc_add_policy_feature(candidate, 18, swap_delta);
        kc_add_policy_feature(candidate, 19, zone == KC_ZONE_HIDDEN ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 20, zone == KC_ZONE_REVEALED ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 21, (double)engine->year / 5.0);
        kc_add_policy_feature(candidate, 22, engine->is_famine ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 23, (double)engine->trick_count / 4.0);
        kc_add_policy_feature(candidate, 24, (double)engine->current_trick_count / 4.0);
        kc_add_policy_feature(candidate, 25, (double)((player_id - engine->lead + KC_PLAYER_COUNT) % KC_PLAYER_COUNT) / 3.0);
        kc_add_policy_feature(candidate, 26, (double)((player_id - engine->trump_selector + KC_PLAYER_COUNT) % KC_PLAYER_COUNT) / 3.0);
        kc_add_policy_feature(candidate, 27, kc_card_matches_suit(card, lead_suit) ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 28, kc_card_matches_suit(card, engine->trump) ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 29, kc_would_currently_win(engine, card) ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 30, (double)current_work / 40.0);
        kc_add_policy_feature(candidate, 31, (double)(current_work < 40 ? 40 - current_work : 0) / 40.0);
        kc_add_policy_feature(candidate, 32, after_work >= 40 ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 33, (double)revealed_job / 5.0);
        kc_add_policy_feature(candidate, 34, suit_is_crop && engine->claimed_jobs[suit] ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 35, (double)player->hand.count / 5.0);
        kc_add_policy_feature(candidate, 36, (double)kc_revealed_plot_count_for_player(player, -1) / 16.0);
        kc_add_policy_feature(candidate, 37, (double)kc_hidden_plot_count_for_player(player, -1) / 16.0);
        kc_add_policy_feature(candidate, 38, (double)kc_total_medals_for_player(engine, player_id) / 20.0);
        kc_add_policy_feature(candidate, 39, (double)own_visible / 100.0);
        kc_add_policy_feature(candidate, 40, (double)own_known / 100.0);
        kc_add_policy_feature(candidate, 41, (double)best_opponent_visible / 100.0);
        kc_add_policy_feature(candidate, 42, kc_card_is_wrecker(card) ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 43, (double)(own_known - best_opponent_visible) / 100.0);
        kc_add_policy_feature(candidate, 44, (double)(own_visible - best_opponent_visible) / 100.0);
        kc_add_policy_feature(candidate, 45, player->has_won_trick_this_year ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 46, player->brigade_leader ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 47, engine->variants.nomenclature ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 48, engine->variants.allow_swap ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 49, engine->variants.northern_style ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 50, engine->variants.mice_variant ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 51, engine->variants.orden_nachalniku ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 52, engine->variants.medals_count ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 53, engine->variants.accumulate_jobs ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 54, engine->variants.hero_of_soviet_union ? 1.0 : 0.0);
        kc_add_policy_feature(candidate, 55, kc_card_is_wrecker(hand_card) ? 1.0 : 0.0);

        for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
            const KCPlayer *seat_player = &engine->players[seat];
            int32_t base = 56 + seat * 10;
            int32_t hand_max = 0;
            int32_t hand_min = 0;
            if (seat == player_id) {
                for (int32_t i = 0; i < seat_player->hand.count; i++) {
                    int32_t value = seat_player->hand.cards[i].value;
                    if (value > hand_max) hand_max = value;
                    if (i == 0 || value < hand_min) hand_min = value;
                }
            }
            kc_add_policy_feature(candidate, base, (double)seat_player->hand.count / 5.0);
            kc_add_policy_feature(candidate, base + 1, (double)kc_revealed_plot_count_for_player(seat_player, -1) / 16.0);
            kc_add_policy_feature(candidate, base + 2, (double)kc_hidden_plot_count_for_player(seat_player, -1) / 16.0);
            kc_add_policy_feature(candidate, base + 3, (double)kc_total_medals_for_player(engine, seat) / 20.0);
            kc_add_policy_feature(candidate, base + 4, seat_player->has_won_trick_this_year ? 1.0 : 0.0);
            kc_add_policy_feature(candidate, base + 5, seat_player->brigade_leader ? 1.0 : 0.0);
            kc_add_policy_feature(candidate, base + 6, (double)kc_visible_score(engine, seat) / 100.0);
            kc_add_policy_feature(candidate, base + 7, (double)(seat == player_id ? kc_known_score_for_player(engine, seat) : kc_visible_score(engine, seat)) / 100.0);
            kc_add_policy_feature(candidate, base + 8, kc_raw_card_value_feature(hand_max));
            kc_add_policy_feature(candidate, base + 9, kc_raw_card_value_feature(hand_min));
        }

        int32_t public_hidden_total = 0;
        for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
            public_hidden_total += kc_hidden_plot_count_for_player(&engine->players[seat], -1);
        }
        for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
            int32_t base = 96 + target * 12;
            int32_t own_hand_count = 0;
            int32_t own_hand_max = 0;
            int32_t own_hand_min = 0;
            int32_t all_revealed = 0;
            int32_t trick_suit_count = 0;
            for (int32_t i = 0; i < player->hand.count; i++) {
                if (!kc_card_matches_suit(player->hand.cards[i], target)) continue;
                int32_t value = player->hand.cards[i].value;
                own_hand_count++;
                if (value > own_hand_max) own_hand_max = value;
                if (own_hand_count == 1 || value < own_hand_min) own_hand_min = value;
            }
            for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
                all_revealed += kc_revealed_plot_count_for_player(&engine->players[seat], target);
            }
            for (int32_t i = 0; i < engine->current_trick_count; i++) {
                if (kc_card_matches_suit(engine->current_trick[i].card, target)) trick_suit_count++;
            }
            for (int32_t i = 0; i < engine->last_trick_count; i++) {
                if (kc_card_matches_suit(engine->last_trick[i].card, target)) trick_suit_count++;
            }
            kc_add_policy_feature(candidate, base, (double)engine->work_hours[target] / 40.0);
            kc_add_policy_feature(candidate, base + 1, (double)(engine->work_hours[target] < 40 ? 40 - engine->work_hours[target] : 0) / 40.0);
            kc_add_policy_feature(candidate, base + 2, engine->has_revealed_job[target] ? (double)engine->revealed_jobs[target].value / 5.0 : 0.0);
            kc_add_policy_feature(candidate, base + 3, engine->claimed_jobs[target] ? 1.0 : 0.0);
            kc_add_policy_feature(candidate, base + 4, (double)own_hand_count / 5.0);
            kc_add_policy_feature(candidate, base + 5, kc_raw_card_value_feature(own_hand_max));
            kc_add_policy_feature(candidate, base + 6, kc_raw_card_value_feature(own_hand_min));
            kc_add_policy_feature(candidate, base + 7, (double)kc_revealed_plot_count_for_player(player, target) / 8.0);
            kc_add_policy_feature(candidate, base + 8, (double)kc_hidden_plot_count_for_player(player, target) / 8.0);
            kc_add_policy_feature(candidate, base + 9, (double)all_revealed / 32.0);
            kc_add_policy_feature(candidate, base + 10, (double)public_hidden_total / 32.0);
            kc_add_policy_feature(candidate, base + 11, (double)trick_suit_count / 8.0);
        }

        kc_add_trick_features(candidate, 144, engine->current_trick, engine->current_trick_count);
        kc_add_trick_features(candidate, 172, engine->last_trick, engine->last_trick_count);
        return;
    }

    kc_add_policy_one_hot(candidate, 0, action_type, 4);
    kc_add_policy_one_hot(candidate, 4, suit, 4);
    kc_add_policy_one_hot(candidate, 8, kc_card_valid(card) ? card.suit : -1, 4);
    kc_add_policy_feature(candidate, 12, kc_card_value_feature(card));
    kc_add_policy_feature(candidate, 13, (double)engine->year / 5.0);
    kc_add_policy_feature(candidate, 14, (double)engine->trick_count / 4.0);
    kc_add_policy_feature(candidate, 15, (double)player->hand.count / 5.0);
    kc_add_policy_feature(candidate, 16, player->has_won_trick_this_year ? 1.0 : 0.0);
    kc_add_policy_one_hot(candidate, 17, lead_suit, 4);
    kc_add_policy_one_hot(candidate, 21, engine->trump, 4);
    kc_add_policy_feature(candidate, 25, (double)current_work / 40.0);
    kc_add_policy_feature(candidate, 26, after_work >= 40 ? 1.0 : 0.0);
    kc_add_policy_feature(candidate, 27, (double)suit_plot_count / 8.0);
    kc_add_policy_feature(candidate, 28, (double)hidden_suit_count / 8.0);
    kc_add_policy_feature(candidate, 29, (double)revealed_job / 5.0);
    kc_add_policy_feature(candidate, 30, kc_would_currently_win(engine, card) ? 1.0 : 0.0);
    kc_add_policy_feature(candidate, 31, zone == KC_ZONE_HIDDEN ? 1.0 : 0.0);
    kc_add_policy_feature(candidate, 32, zone == KC_ZONE_REVEALED ? 1.0 : 0.0);
    kc_add_policy_feature(candidate, 33, swap_delta);

    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t count = 0;
        for (int32_t i = 0; i < player->hand.count; i++) {
            if (kc_card_matches_suit(player->hand.cards[i], target)) count++;
        }
        kc_add_policy_feature(candidate, 34 + target, (double)count / 5.0);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t count = 0;
        for (int32_t i = 0; i < player->hand.count; i++) {
            if (kc_card_matches_suit(player->hand.cards[i], target) && player->hand.cards[i].value >= 11) count++;
        }
        kc_add_policy_feature(candidate, 38 + target, (double)count / 5.0);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t max_value = 0;
        for (int32_t i = 0; i < player->hand.count; i++) {
            if (kc_card_matches_suit(player->hand.cards[i], target) && player->hand.cards[i].value > max_value) max_value = player->hand.cards[i].value;
        }
        kc_add_policy_feature(candidate, 42 + target, kc_raw_card_value_feature(max_value));
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t min_value = 0;
        bool found = false;
        for (int32_t i = 0; i < player->hand.count; i++) {
            if (kc_card_matches_suit(player->hand.cards[i], target) &&
                (!found || player->hand.cards[i].value < min_value)) {
                min_value = player->hand.cards[i].value;
                found = true;
            }
        }
        kc_add_policy_feature(candidate, 46 + target, kc_raw_card_value_feature(min_value));
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t count = 0;
        for (int32_t i = 0; i < player->plot_revealed.count; i++) {
            if (kc_card_matches_suit(player->plot_revealed.cards[i], target)) count++;
        }
        kc_add_policy_feature(candidate, 50 + target, (double)count / 8.0);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        int32_t count = 0;
        for (int32_t i = 0; i < player->plot_hidden.count; i++) {
            if (kc_card_matches_suit(player->plot_hidden.cards[i], target)) count++;
        }
        kc_add_policy_feature(candidate, 54 + target, (double)count / 8.0);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        kc_add_policy_feature(candidate, 58 + target, engine->has_revealed_job[target] ? (double)engine->revealed_jobs[target].value / 5.0 : 0.0);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        kc_add_policy_feature(candidate, 62 + target, (double)engine->work_hours[target] / 40.0);
    }
    for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
        kc_add_policy_feature(candidate, 66 + target, engine->claimed_jobs[target] ? 1.0 : 0.0);
    }
    kc_add_policy_one_hot(candidate, 70, kc_card_valid(hand_card) ? hand_card.suit : -1, KC_SUIT_COUNT);
    kc_add_policy_feature(candidate, 74, kc_card_value_feature(hand_card));
    kc_add_policy_feature(candidate, 75, kc_card_matches_suit(card, engine->trump) ? 1.0 : 0.0);
    kc_add_policy_feature(candidate, 76, kc_card_matches_suit(card, lead_suit) ? 1.0 : 0.0);
    kc_add_policy_feature(candidate, 77, (double)kc_total_medals_for_player(engine, player_id) / 20.0);
    kc_add_policy_feature(candidate, 78, (double)engine->current_trick_count / 4.0);
    int32_t own_score = kc_known_score_for_player(engine, player_id);
    int32_t best_opponent = -1000000;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == player_id) continue;
        int32_t opponent_score = kc_visible_score(engine, other);
        if (opponent_score > best_opponent) best_opponent = opponent_score;
    }
    kc_add_policy_feature(candidate, 79, (double)own_score / 100.0);
    kc_add_policy_feature(candidate, 80, (double)best_opponent / 100.0);
    kc_add_policy_feature(candidate, 81, (double)(own_score - best_opponent) / 100.0);
    kc_add_policy_feature(candidate, 82, suit == engine->trump ? 1.0 : 0.0);
    kc_add_policy_one_hot(candidate, 83, player_id, KC_PLAYER_COUNT);
    kc_add_policy_one_hot(candidate, 87, (player_id - engine->lead + KC_PLAYER_COUNT) % KC_PLAYER_COUNT, KC_PLAYER_COUNT);
    kc_add_policy_one_hot(candidate, 91, (player_id - engine->trump_selector + KC_PLAYER_COUNT) % KC_PLAYER_COUNT, KC_PLAYER_COUNT);
}

int32_t kc_policy_candidates(const KCEngine *engine, int32_t player_id, KCPolicyModelBuffer model, KCPolicyActionCandidate *candidates, int32_t max_candidates, double *hidden_cache) {
    int32_t count = 0;
    int32_t activation_count = kc_policy_activation_count(model);
    if (engine->phase == KC_PHASE_PLANNING) {
        for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_candidates; suit++) {
            KCAction action = { .kind = KC_ACTION_SET_TRUMP, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            candidates[count].action = action;
            candidates[count].has_features = true;
            candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
            kc_policy_features(engine, player_id, 0, suit, kc_no_card(), kc_no_card(), -1, 0, model.input_size, &candidates[count]);
            candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
            count++;
        }
    } else if (engine->phase == KC_PHASE_SWAP) {
        KCAction no_swap = { .kind = KC_ACTION_CONFIRM_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
        candidates[count].action = no_swap;
        candidates[count].has_features = true;
        candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
        kc_policy_features(engine, player_id, 1, -1, kc_no_card(), kc_no_card(), -1, 0, model.input_size, &candidates[count]);
        candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
        count++;
        if (!engine->swap_count[player_id]) {
            const KCPlayer *player = &engine->players[player_id];
            for (int32_t hand_index = 0; hand_index < player->hand.count; hand_index++) {
                KCCard hand_card = player->hand.cards[hand_index];
                for (int32_t plot_index = 0; plot_index < player->plot_hidden.count && count < max_candidates; plot_index++) {
                    KCCard plot_card = player->plot_hidden.cards[plot_index];
                    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = hand_card, .plot_card = plot_card, .plot_zone = KC_ZONE_HIDDEN, .target_suit = -1 };
                    candidates[count].action = action;
                    candidates[count].has_features = true;
                    candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_HIDDEN, (double)(plot_card.value - hand_card.value) / (double)KC_POLICY_CARD_VALUE_SCALE, model.input_size, &candidates[count]);
                    candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
                    count++;
                }
                for (int32_t plot_index = 0; plot_index < player->plot_revealed.count && count < max_candidates; plot_index++) {
                    KCCard plot_card = player->plot_revealed.cards[plot_index];
                    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = hand_card, .plot_card = plot_card, .plot_zone = KC_ZONE_REVEALED, .target_suit = -1 };
                    candidates[count].action = action;
                    candidates[count].has_features = true;
                    candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_REVEALED, (double)(plot_card.value - hand_card.value) / (double)KC_POLICY_CARD_VALUE_SCALE, model.input_size, &candidates[count]);
                    candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
                    count++;
                }
            }
        }
    } else if (engine->phase == KC_PHASE_TRICK) {
        const KCCardList *hand = &engine->players[player_id].hand;
        for (int32_t card_index = 0; card_index < hand->count && count < max_candidates; card_index++) {
            if (!kc_is_valid_play(engine, player_id, card_index)) {
                continue;
            }
            KCCard card = hand->cards[card_index];
            KCAction action = { .kind = KC_ACTION_PLAY_CARD, .player_id = player_id, .suit = -1, .card = card, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            candidates[count].action = action;
            candidates[count].has_features = true;
            candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
            kc_policy_features(engine, player_id, 2, card.suit, card, kc_no_card(), -1, 0, model.input_size, &candidates[count]);
            candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
            count++;
        }
    } else if (engine->phase == KC_PHASE_ASSIGNMENT) {
        int32_t play_index = -1;
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (engine->pending_assignment_targets[i] < 0) {
                play_index = i;
                break;
            }
        }
        if (play_index >= 0) {
            KCCard assigned_card = engine->last_trick[play_index].card;
            for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_candidates; suit++) {
                if (!kc_assignment_target_legal(engine, suit)) {
                    continue;
                }
                KCAction action = { .kind = KC_ACTION_ASSIGN, .player_id = player_id, .suit = -1, .card = assigned_card, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = suit };
                candidates[count].action = action;
                candidates[count].has_features = true;
                candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
                kc_policy_features(engine, player_id, 3, suit, assigned_card, kc_no_card(), -1, 0, model.input_size, &candidates[count]);
                candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
                count++;
            }
        }
    }
    return count;
}

int32_t kc_engine_policy_action_features(const KCEngine *engine, int32_t player_id, int32_t input_size, KCPolicyActionFeatures *features, int32_t max_features) {
    if (!engine || !features || max_features <= 0 || input_size <= 0) {
        return 0;
    }
    KCPolicyActionCandidate candidate;
    int32_t count = 0;
    if (engine->phase == KC_PHASE_PLANNING) {
        for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_features; suit++) {
            memset(&candidate, 0, sizeof(candidate));
            candidate.action = (KCAction){ .kind = KC_ACTION_SET_TRUMP, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            kc_policy_features(engine, player_id, 0, suit, kc_no_card(), kc_no_card(), -1, 0, input_size, &candidate);
            features[count].action = candidate.action;
            features[count].action_head = candidate.action_head;
            features[count].feature_count = candidate.feature_count;
            memcpy(features[count].feature_indices, candidate.feature_indices, sizeof(candidate.feature_indices));
            memcpy(features[count].feature_values, candidate.feature_values, sizeof(candidate.feature_values));
            count++;
        }
    } else if (engine->phase == KC_PHASE_SWAP) {
        memset(&candidate, 0, sizeof(candidate));
        candidate.action = (KCAction){ .kind = KC_ACTION_CONFIRM_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
        kc_policy_features(engine, player_id, 1, -1, kc_no_card(), kc_no_card(), -1, 0, input_size, &candidate);
        features[count].action = candidate.action;
        features[count].action_head = candidate.action_head;
        features[count].feature_count = candidate.feature_count;
        memcpy(features[count].feature_indices, candidate.feature_indices, sizeof(candidate.feature_indices));
        memcpy(features[count].feature_values, candidate.feature_values, sizeof(candidate.feature_values));
        count++;
        if (!engine->swap_count[player_id]) {
            const KCPlayer *player = &engine->players[player_id];
            for (int32_t hand_index = 0; hand_index < player->hand.count; hand_index++) {
                KCCard hand_card = player->hand.cards[hand_index];
                for (int32_t plot_index = 0; plot_index < player->plot_hidden.count && count < max_features; plot_index++) {
                    KCCard plot_card = player->plot_hidden.cards[plot_index];
                    memset(&candidate, 0, sizeof(candidate));
                    candidate.action = (KCAction){ .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = hand_card, .plot_card = plot_card, .plot_zone = KC_ZONE_HIDDEN, .target_suit = -1 };
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_HIDDEN, (double)(plot_card.value - hand_card.value) / (double)KC_POLICY_CARD_VALUE_SCALE, input_size, &candidate);
                    features[count].action = candidate.action;
                    features[count].action_head = candidate.action_head;
                    features[count].feature_count = candidate.feature_count;
                    memcpy(features[count].feature_indices, candidate.feature_indices, sizeof(candidate.feature_indices));
                    memcpy(features[count].feature_values, candidate.feature_values, sizeof(candidate.feature_values));
                    count++;
                }
                for (int32_t plot_index = 0; plot_index < player->plot_revealed.count && count < max_features; plot_index++) {
                    KCCard plot_card = player->plot_revealed.cards[plot_index];
                    memset(&candidate, 0, sizeof(candidate));
                    candidate.action = (KCAction){ .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = hand_card, .plot_card = plot_card, .plot_zone = KC_ZONE_REVEALED, .target_suit = -1 };
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_REVEALED, (double)(plot_card.value - hand_card.value) / (double)KC_POLICY_CARD_VALUE_SCALE, input_size, &candidate);
                    features[count].action = candidate.action;
                    features[count].action_head = candidate.action_head;
                    features[count].feature_count = candidate.feature_count;
                    memcpy(features[count].feature_indices, candidate.feature_indices, sizeof(candidate.feature_indices));
                    memcpy(features[count].feature_values, candidate.feature_values, sizeof(candidate.feature_values));
                    count++;
                }
            }
        }
    } else if (engine->phase == KC_PHASE_TRICK) {
        const KCCardList *hand = &engine->players[player_id].hand;
        for (int32_t card_index = 0; card_index < hand->count && count < max_features; card_index++) {
            if (!kc_is_valid_play(engine, player_id, card_index)) {
                continue;
            }
            KCCard card = hand->cards[card_index];
            memset(&candidate, 0, sizeof(candidate));
            candidate.action = (KCAction){ .kind = KC_ACTION_PLAY_CARD, .player_id = player_id, .suit = -1, .card = card, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            kc_policy_features(engine, player_id, 2, card.suit, card, kc_no_card(), -1, 0, input_size, &candidate);
            features[count].action = candidate.action;
            features[count].action_head = candidate.action_head;
            features[count].feature_count = candidate.feature_count;
            memcpy(features[count].feature_indices, candidate.feature_indices, sizeof(candidate.feature_indices));
            memcpy(features[count].feature_values, candidate.feature_values, sizeof(candidate.feature_values));
            count++;
        }
    } else if (engine->phase == KC_PHASE_ASSIGNMENT) {
        int32_t play_index = -1;
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (engine->pending_assignment_targets[i] < 0) {
                play_index = i;
                break;
            }
        }
        if (play_index >= 0) {
            KCCard assigned_card = engine->last_trick[play_index].card;
            for (int32_t suit = 0; suit < KC_SUIT_COUNT && count < max_features; suit++) {
                if (!kc_assignment_target_legal(engine, suit)) {
                    continue;
                }
                memset(&candidate, 0, sizeof(candidate));
                candidate.action = (KCAction){ .kind = KC_ACTION_ASSIGN, .player_id = player_id, .suit = -1, .card = assigned_card, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = suit };
                kc_policy_features(engine, player_id, 3, suit, assigned_card, kc_no_card(), -1, 0, input_size, &candidate);
                features[count].action = candidate.action;
                features[count].action_head = candidate.action_head;
                features[count].feature_count = candidate.feature_count;
                memcpy(features[count].feature_indices, candidate.feature_indices, sizeof(candidate.feature_indices));
                memcpy(features[count].feature_values, candidate.feature_values, sizeof(candidate.feature_values));
                count++;
            }
        }
    }
    return count;
}

static int32_t kc_dense_action_id(int32_t value, int32_t offset, int32_t count) {
    int32_t item = value + offset;
    if (item < 0) return 0;
    if (item >= count) return count - 1;
    return item;
}

static void kc_policy_action_scalars(const KCEngine *engine, int32_t player_id, KCAction action, int32_t action_head, int32_t candidate_count, float *scalars, int32_t scalar_count) {
    if (!engine || !scalars || scalar_count <= 0 || player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return;
    }
    for (int32_t index = 0; index < scalar_count; index++) {
        scalars[index] = 0.0f;
    }

    const KCPlayer *player = &engine->players[player_id];
    KCCard action_card = kc_no_card();
    if (kc_card_valid(action.card)) {
        action_card = action.card;
    } else if (kc_card_valid(action.plot_card)) {
        action_card = action.plot_card;
    } else if (kc_card_valid(action.hand_card)) {
        action_card = action.hand_card;
    }

    int32_t target_suit = action.target_suit;
    if (target_suit < 0 && action.suit >= 0) {
        target_suit = action.suit;
    }
    if (target_suit < 0 && kc_card_valid(action_card)) {
        target_suit = action_card.suit;
    }

    bool target_valid = target_suit >= 0 && target_suit < KC_SUIT_COUNT;
    int32_t current_work = target_valid ? engine->work_hours[target_suit] : 0;
    int32_t pending_work = 0;
    if (target_valid) {
        for (int32_t index = 0; index < engine->last_trick_count; index++) {
            if (engine->pending_assignment_targets[index] == target_suit) {
                pending_work += kc_work_value(engine, engine->last_trick[index].card);
            }
        }
    }
    int32_t action_work = kc_card_valid(action_card) ? kc_work_value(engine, action_card) : 0;
    int32_t projected_work = current_work + pending_work;
    if (action.kind == KC_ACTION_ASSIGN || action.kind == KC_ACTION_PLAY_CARD) {
        projected_work += action_work;
    }

    int32_t own_hand_count = 0;
    int32_t own_hand_max = 0;
    int32_t own_hand_min = 0;
    if (target_suit >= 0) {
        for (int32_t index = 0; index < player->hand.count; index++) {
            KCCard card = player->hand.cards[index];
            if (!kc_card_matches_suit(card, target_suit)) {
                continue;
            }
            own_hand_count++;
            if (card.value > own_hand_max) {
                own_hand_max = card.value;
            }
            if (own_hand_count == 1 || card.value < own_hand_min) {
                own_hand_min = card.value;
            }
        }
    }

    int32_t visible_plot_count = 0;
    if (target_suit >= 0) {
        for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
            visible_plot_count += kc_revealed_plot_count_for_player(&engine->players[seat], target_suit);
        }
    }

    int32_t own_known = kc_known_score_for_player(engine, player_id);
    int32_t best_opponent_visible = -1000000;
    for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
        if (seat == player_id) {
            continue;
        }
        int32_t visible = kc_visible_score(engine, seat);
        if (visible > best_opponent_visible) {
            best_opponent_visible = visible;
        }
    }
    if (best_opponent_visible < 0) {
        best_opponent_visible = 0;
    }

    int32_t lead_suit = kc_lead_suit(engine);
    double swap_delta = 0.0;
    if (kc_card_valid(action.plot_card) && kc_card_valid(action.hand_card)) {
        swap_delta = (double)(action.plot_card.value - action.hand_card.value) / (double)KC_POLICY_CARD_VALUE_SCALE;
    }
    if (scalar_count > 0) scalars[0] = (float)((double)action_head / 3.0);
    if (scalar_count > 1) scalars[1] = (float)((double)candidate_count / 16.0);
    if (scalar_count > 2) scalars[2] = (float)((double)action.kind / 8.0);
    if (scalar_count > 3) scalars[3] = target_valid ? (float)((double)target_suit / 3.0) : 0.0f;
    if (scalar_count > 4) scalars[4] = (float)kc_card_value_feature(action_card);
    if (scalar_count > 5) scalars[5] = (float)kc_card_value_feature(action.hand_card);
    if (scalar_count > 6) scalars[6] = (float)kc_card_value_feature(action.plot_card);
    if (scalar_count > 7) scalars[7] = (float)swap_delta;
    if (scalar_count > 8) scalars[8] = kc_card_matches_suit(action_card, lead_suit) ? 1.0f : 0.0f;
    if (scalar_count > 9) scalars[9] = kc_card_matches_suit(action_card, engine->trump) ? 1.0f : 0.0f;
    if (scalar_count > 10) scalars[10] = kc_would_currently_win(engine, action_card) ? 1.0f : 0.0f;
    if (scalar_count > 11) scalars[11] = (float)((double)engine->current_trick_count / 4.0);
    if (scalar_count > 12) scalars[12] = (float)((double)pending_work / 40.0);
    if (scalar_count > 13) scalars[13] = (float)((double)current_work / 40.0);
    if (scalar_count > 14) scalars[14] = (float)((double)action_work / 40.0);
    if (scalar_count > 15) scalars[15] = (float)((double)projected_work / 40.0);
    if (scalar_count > 16) scalars[16] = (float)((double)(projected_work < 40 ? 40 - projected_work : 0) / 40.0);
    if (scalar_count > 17) scalars[17] = projected_work >= 40 ? 1.0f : 0.0f;
    if (scalar_count > 18) scalars[18] = target_valid && engine->has_revealed_job[target_suit] ? (float)((double)engine->revealed_jobs[target_suit].value / 5.0) : 0.0f;
    if (scalar_count > 19) scalars[19] = target_valid && engine->claimed_jobs[target_suit] ? 1.0f : 0.0f;
    if (scalar_count > 20) scalars[20] = (float)((double)own_hand_count / 5.0);
    if (scalar_count > 21) scalars[21] = (float)kc_raw_card_value_feature(own_hand_max);
    if (scalar_count > 22) scalars[22] = (float)kc_raw_card_value_feature(own_hand_min);
    if (scalar_count > 23) scalars[23] = target_valid ? (float)((double)kc_hidden_plot_count_for_player(player, target_suit) / 8.0) : 0.0f;
    if (scalar_count > 24) scalars[24] = target_valid ? (float)((double)kc_revealed_plot_count_for_player(player, target_suit) / 8.0) : 0.0f;
    if (scalar_count > 25) scalars[25] = (float)((double)visible_plot_count / 32.0);
    if (scalar_count > 26) scalars[26] = (float)((double)(own_known - best_opponent_visible) / 100.0);
    if (scalar_count > 27) scalars[27] = (float)((double)own_known / 100.0);
    if (scalar_count > 28) scalars[28] = (float)((double)best_opponent_visible / 100.0);
    if (scalar_count > 29) scalars[29] = action.kind == KC_ACTION_ASSIGN && target_valid && kc_assignment_target_legal(engine, target_suit) ? 1.0f : 0.0f;
    if (scalar_count > 30) scalars[30] = engine->lead >= 0 ? (float)((double)((player_id - engine->lead + KC_PLAYER_COUNT) % KC_PLAYER_COUNT) / 3.0) : 0.0f;
    if (scalar_count > 31) scalars[31] = kc_card_is_wrecker(action_card) ? 1.0f : 0.0f;
}

int32_t kc_engine_policy_action_dense_features(const KCEngine *engine, int32_t player_id, KCDensePolicyActionFeatures output) {
    if (!engine || output.max_actions <= 0 || output.input_size <= 0) {
        return 0;
    }
    int32_t capacity = output.max_actions < 256 ? output.max_actions : 256;
    KCPolicyActionFeatures sparse[256];
    int32_t count = kc_engine_policy_action_features(engine, player_id, output.input_size, sparse, capacity);
    if (output.features) {
        memset(output.features, 0, (size_t)capacity * (size_t)output.input_size * sizeof(float));
    }
    if (output.action_scalars && output.action_scalar_count > 0) {
        memset(output.action_scalars, 0, (size_t)capacity * (size_t)output.action_scalar_count * sizeof(float));
    }
    for (int32_t row = 0; row < count; row++) {
        KCPolicyActionFeatures *candidate = &sparse[row];
        KCAction action = candidate->action;
        if (output.actions) output.actions[row] = action;
        if (output.action_heads) output.action_heads[row] = candidate->action_head;
        if (output.kind_ids) output.kind_ids[row] = kc_dense_action_id(action.kind, 0, 10);
        if (output.player_ids) output.player_ids[row] = kc_dense_action_id(action.player_id, 1, 6);
        if (output.suit_ids) output.suit_ids[row] = kc_dense_action_id(action.suit, 1, 6);
        if (output.target_suit_ids) output.target_suit_ids[row] = kc_dense_action_id(action.target_suit, 1, 6);
        if (output.card_suit_ids) output.card_suit_ids[row] = kc_dense_action_id(action.card.suit, 1, 6);
        if (output.card_value_ids) output.card_value_ids[row] = kc_dense_action_id(action.card.value, 0, 16);
        if (output.hand_suit_ids) output.hand_suit_ids[row] = kc_dense_action_id(action.hand_card.suit, 1, 6);
        if (output.hand_value_ids) output.hand_value_ids[row] = kc_dense_action_id(action.hand_card.value, 0, 16);
        if (output.plot_suit_ids) output.plot_suit_ids[row] = kc_dense_action_id(action.plot_card.suit, 1, 6);
        if (output.plot_value_ids) output.plot_value_ids[row] = kc_dense_action_id(action.plot_card.value, 0, 16);
        if (output.plot_zone_ids) output.plot_zone_ids[row] = kc_dense_action_id(action.plot_zone, 1, 16);
        if (output.action_scalars && output.action_scalar_count > 0) {
            kc_policy_action_scalars(
                engine,
                player_id,
                action,
                candidate->action_head,
                count,
                output.action_scalars + ((size_t)row * (size_t)output.action_scalar_count),
                output.action_scalar_count
            );
        }
        if (!output.features) {
            continue;
        }
        float *dense = output.features + ((size_t)row * (size_t)output.input_size);
        for (int32_t index = 0; index < candidate->feature_count; index++) {
            int32_t column = candidate->feature_indices[index];
            if (column >= 0 && column < output.input_size) {
                dense[column] = (float)candidate->feature_values[index];
            }
        }
    }
    return count;
}

bool kc_sample_policy_action(KCPolicyActionCandidate *candidates, int32_t count, KCPolicyModelBuffer model, uint64_t *rng_state, double temperature, double greedy_sample_rate, double *gradient, KCAction *selected) {
    if (count <= 0) {
        return false;
    }
    double safe_temperature = temperature > 0.05 ? temperature : 0.05;
    double logits[256];
    double max_logit = 0;
    for (int32_t index = 0; index < count; index++) {
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
    double draw = kc_uniform_from_state(rng_state) * total;
    int32_t chosen = count - 1;
    if (greedy_sample_rate > 0 && kc_uniform_from_state(rng_state) < greedy_sample_rate) {
        chosen = 0;
        for (int32_t index = 1; index < count; index++) {
            if (candidates[index].score > candidates[chosen].score) {
                chosen = index;
            }
        }
    } else {
        for (int32_t index = 0; index < count; index++) {
            draw -= weights[index];
            if (draw <= 0) {
                chosen = index;
                break;
            }
        }
    }

    if (candidates[chosen].has_features) {
        kc_add_cached_score_gradient(model, &candidates[chosen], 1.0 / safe_temperature, gradient);
    }
    for (int32_t index = 0; index < count; index++) {
        if (!candidates[index].has_features) {
            continue;
        }
        kc_add_cached_score_gradient(model, &candidates[index], -(weights[index] / total) / safe_temperature, gradient);
    }
    *selected = candidates[chosen].action;
    return true;
}

bool kc_sample_policy_choice(KCPolicyActionCandidate *candidates, int32_t count, uint64_t *rng_state, double temperature, double greedy_sample_rate, int32_t *chosen_out, double *log_probability_out) {
    if (count <= 0) {
        return false;
    }
    double safe_temperature = temperature > 0.05 ? temperature : 0.05;
    double logits[256];
    double max_logit = 0;
    for (int32_t index = 0; index < count; index++) {
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
    double draw = kc_uniform_from_state(rng_state) * total;
    int32_t chosen = count - 1;
    if (greedy_sample_rate > 0 && kc_uniform_from_state(rng_state) < greedy_sample_rate) {
        chosen = 0;
        for (int32_t index = 1; index < count; index++) {
            if (candidates[index].score > candidates[chosen].score) {
                chosen = index;
            }
        }
    } else {
        for (int32_t index = 0; index < count; index++) {
            draw -= weights[index];
            if (draw <= 0) {
                chosen = index;
                break;
            }
        }
    }

    *chosen_out = chosen;
    if (log_probability_out) {
        *log_probability_out = logits[chosen] - (log(total) + max_logit);
    }
    return true;
}

double kc_policy_choice_log_probability(const KCPolicyActionCandidate *candidates, int32_t count, int32_t chosen, double temperature) {
    if (count <= 0 || chosen < 0 || chosen >= count) {
        return 0;
    }
    double safe_temperature = temperature > 0.05 ? temperature : 0.05;
    double max_logit = 0;
    double chosen_logit = 0;
    for (int32_t index = 0; index < count; index++) {
        double logit = candidates[index].score / safe_temperature;
        if (index == chosen) {
            chosen_logit = logit;
        }
        if (index == 0 || logit > max_logit) {
            max_logit = logit;
        }
    }
    double total = 0;
    for (int32_t index = 0; index < count; index++) {
        total += exp((candidates[index].score / safe_temperature) - max_logit);
    }
    if (total <= 0) {
        return 0;
    }
    return chosen_logit - (log(total) + max_logit);
}

static bool kc_submit_prefilled_assignment_action(const KCEngine *engine, int32_t player_id, KCAction *selected) {
    if (engine && selected && engine->phase == KC_PHASE_ASSIGNMENT &&
        kc_pending_assignment_count(engine) >= engine->last_trick_count) {
        *selected = (KCAction){
            .kind = KC_ACTION_SUBMIT_ASSIGNMENTS,
            .player_id = player_id,
            .suit = -1,
            .card = kc_no_card(),
            .hand_card = kc_no_card(),
            .plot_card = kc_no_card(),
            .plot_zone = -1,
            .target_suit = -1
        };
        return true;
    }
    return false;
}

struct KCPolicyWorkspace {
    int32_t activation_count;
    KCPolicyActionCandidate candidates[256];
    double hidden_cache[];
};

KCPolicyWorkspace *kc_policy_workspace_alloc(KCPolicyModelBuffer model) {
    int32_t activation_count = kc_policy_activation_count(model);
    if (activation_count <= 0 || activation_count > KC_MAX_POLICY_ACTIVATIONS) {
        return NULL;
    }
    KCPolicyWorkspace *workspace = malloc(sizeof(KCPolicyWorkspace) + (size_t)256 * (size_t)activation_count * sizeof(double));
    if (workspace) {
        workspace->activation_count = activation_count;
    }
    return workspace;
}

void kc_policy_workspace_free(KCPolicyWorkspace *workspace) {
    free(workspace);
}

bool kc_greedy_policy_action(const KCEngine *engine, int32_t player_id, KCPolicyModelBuffer model, KCPolicyActionCandidate *candidates, double *hidden_cache, KCAction *selected) {
    if (kc_submit_prefilled_assignment_action(engine, player_id, selected)) {
        return true;
    }
    if (!candidates || !hidden_cache) {
        return false;
    }
    int32_t count = kc_policy_candidates(engine, player_id, model, candidates, 256, hidden_cache);
    if (count <= 0) {
        return false;
    }
    int32_t best = 0;
    for (int32_t index = 1; index < count; index++) {
        if (candidates[index].score > candidates[best].score) {
            best = index;
        }
    }
    *selected = candidates[best].action;
    return true;
}

static bool kc_policy_action_equal(KCAction lhs, KCAction rhs) {
    return lhs.kind == rhs.kind
        && lhs.player_id == rhs.player_id
        && lhs.suit == rhs.suit
        && kc_card_equal(lhs.card, rhs.card)
        && kc_card_equal(lhs.hand_card, rhs.hand_card)
        && kc_card_equal(lhs.plot_card, rhs.plot_card)
        && lhs.plot_zone == rhs.plot_zone
        && lhs.target_suit == rhs.target_suit;
}

int32_t kc_policy_candidate_index_for_action(const KCPolicyActionCandidate *candidates, int32_t count, KCAction action) {
    for (int32_t index = 0; index < count; index++) {
        if (kc_policy_action_equal(candidates[index].action, action)) {
            return index;
        }
    }
    return -1;
}

double kc_imitation_weight_for_head(KCPolicyGradientConfig config, int32_t action_head) {
    double override = -1.0;
    switch (action_head) {
    case 0:
        override = config.imitation_trump_weight;
        break;
    case 1:
        override = config.imitation_swap_weight;
        break;
    case 2:
        override = config.imitation_play_weight;
        break;
    case 3:
        override = config.imitation_assign_weight;
        break;
    default:
        break;
    }
    return override >= 0 ? override : config.imitation_weight;
}

int32_t kc_apply_policy_action(KCEngine *engine, KCAction action) {
    if (action.kind == KC_ACTION_ASSIGN) {
        int32_t error = kc_engine_apply(engine, action);
        if (error != 0) {
            return error;
        }
        if (engine->phase == KC_PHASE_ASSIGNMENT && kc_pending_assignment_count(engine) >= engine->last_trick_count) {
            KCAction submit = { .kind = KC_ACTION_SUBMIT_ASSIGNMENTS, .player_id = action.player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            return kc_engine_apply(engine, submit);
        }
        return 0;
    }
    int32_t error = kc_engine_apply(engine, action);
    if (error != 0) {
        return error;
    }
    if (action.kind == KC_ACTION_SWAP) {
        KCAction confirm = { .kind = KC_ACTION_CONFIRM_SWAP, .player_id = action.player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
        return kc_engine_apply(engine, confirm);
    }
    return 0;
}

int32_t kc_engine_apply_ai_action(KCEngine *engine, KCAction action) {
    kc_engine_begin_transition_batch(engine);
    int32_t error = kc_apply_policy_action(engine, action);
    kc_engine_end_transition_batch(engine);
    return error;
}

int32_t kc_engine_apply_ai_action_stepwise(KCEngine *engine, KCAction action) {
    kc_engine_begin_transition_batch(engine);
    if (action.kind == KC_ACTION_ASSIGN) {
        int32_t error = kc_engine_apply_manual(engine, action);
        if (error != 0) {
            kc_engine_end_transition_batch(engine);
            return error;
        }
        if (engine->phase == KC_PHASE_ASSIGNMENT && kc_pending_assignment_count(engine) >= engine->last_trick_count) {
            KCAction submit = { .kind = KC_ACTION_SUBMIT_ASSIGNMENTS, .player_id = action.player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            error = kc_engine_apply_manual(engine, submit);
        }
        kc_engine_end_transition_batch(engine);
        return error;
    }
    int32_t error = kc_engine_apply_manual(engine, action);
    if (error != 0) {
        kc_engine_end_transition_batch(engine);
        return error;
    }
    if (action.kind == KC_ACTION_SWAP) {
        KCAction confirm = { .kind = KC_ACTION_CONFIRM_SWAP, .player_id = action.player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
        error = kc_engine_apply_manual(engine, confirm);
    }
    kc_engine_end_transition_batch(engine);
    return error;
}

int32_t kc_engine_apply_policy_action(KCEngine *engine, KCAction action) {
    return kc_engine_apply_ai_action(engine, action);
}

bool kc_engine_policy_action_with_workspace(const KCEngine *engine, KCPolicyModelBuffer model, KCPolicyWorkspace *workspace, KCAction *selected) {
    if (!engine) {
        return false;
    }
    if (engine->phase == KC_PHASE_PASS) {
        return kc_engine_heuristic_action(engine, selected);
    }
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_policy(engine->controllers.seats[player_id])) {
        return false;
    }
    KCAction legal_actions[4];
    int32_t legal_count = kc_engine_legal_actions(engine, legal_actions, 4);
    if (legal_count == 1 &&
        (legal_actions[0].kind == KC_ACTION_REVEAL_REWARD ||
         legal_actions[0].kind == KC_ACTION_REVEAL_TRUMP)) {
        *selected = legal_actions[0];
        return true;
    }
    if (engine->phase == KC_PHASE_PLANNING && engine->is_famine) {
        return false;
    }
    if (kc_submit_prefilled_assignment_action(engine, player_id, selected)) {
        return true;
    }
    if (!workspace || workspace->activation_count != kc_policy_activation_count(model)) {
        return false;
    }
    return kc_greedy_policy_action(engine, player_id, model, workspace->candidates, workspace->hidden_cache, selected);
}

bool kc_engine_policy_action(const KCEngine *engine, KCPolicyModelBuffer model, KCAction *selected) {
    KCPolicyWorkspace *workspace = kc_policy_workspace_alloc(model);
    if (!workspace) {
        return false;
    }
    bool ok = kc_engine_policy_action_with_workspace(engine, model, workspace, selected);
    kc_policy_workspace_free(workspace);
    return ok;
}

int32_t kc_engine_step_policy_automatic_with_workspace(KCEngine *engine, KCPolicyModelBuffer model, KCPolicyWorkspace *workspace) {
    if (!engine) {
        return 0;
    }
    if (engine->phase == KC_PHASE_PLANNING && engine->is_famine &&
        kc_engine_legal_actions(engine, NULL, 0) == 0) {
        kc_advance_from_planning(engine);
        return 1;
    }
    KCAction selected;
    bool ok = kc_engine_policy_action_with_workspace(engine, model, workspace, &selected);
    if (!ok) {
        return 0;
    }
    int32_t error = kc_apply_policy_action(engine, selected);
    return error == 0 ? 1 : -error;
}

int32_t kc_engine_step_policy_automatic(KCEngine *engine, KCPolicyModelBuffer model) {
    KCPolicyWorkspace *workspace = kc_policy_workspace_alloc(model);
    if (!workspace) {
        return 0;
    }
    int32_t result = kc_engine_step_policy_automatic_with_workspace(engine, model, workspace);
    kc_policy_workspace_free(workspace);
    return result;
}

static int32_t kc_run_greedy_model_game(uint64_t seed, KCVariants variants, KCPolicyModelBuffer model, int32_t *scores, int32_t *medals, int32_t *winner_id) {
    KCEngine engine;
    kc_engine_init(&engine, seed, variants);
    KCPolicyWorkspace *workspace = kc_policy_workspace_alloc(model);
    if (!workspace) {
        return 2;
    }
    int32_t guard_count = 0;
    while (engine.phase != KC_PHASE_GAME_OVER && guard_count < 2000) {
        guard_count++;
        if (engine.phase == KC_PHASE_REQUISITION) {
            KCAction action = { .kind = KC_ACTION_CONTINUE_AFTER_REQUISITION, .player_id = 0, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            kc_engine_apply(&engine, action);
            continue;
        }
        int32_t player_id = engine.phase == KC_PHASE_ASSIGNMENT ? engine.last_winner : engine.current_player;
        KCAction selected;
        if (!kc_greedy_policy_action(&engine, player_id, model, workspace->candidates, workspace->hidden_cache, &selected)) {
            kc_policy_workspace_free(workspace);
            return 3;
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            kc_policy_workspace_free(workspace);
            return 10 + error;
        }
    }
    kc_policy_workspace_free(workspace);
    if (engine.phase != KC_PHASE_GAME_OVER) {
        return 4;
    }
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        scores[player_id] = kc_final_score(&engine, player_id);
        medals[player_id] = kc_total_medals_for_player(&engine, player_id);
    }
    *winner_id = engine.winner_id;
    return 0;
}

int32_t kc_run_greedy_matchup_game(
    uint64_t seed,
    KCVariants variants,
    KCPolicyModelBuffer model,
    KCPolicyModelBuffer opponent_model,
    bool opponent_is_heuristic,
    int32_t model_seat,
    bool round_curriculum,
    int32_t round_plot_cards,
    double round_famine_rate,
    int32_t *scores,
    int32_t *medals,
    int32_t *winner_id
) {
    KCEngine engine;
    if (round_curriculum) {
        kc_engine_init_curriculum(&engine, seed, variants, round_plot_cards, round_famine_rate);
    } else {
        kc_engine_init(&engine, seed, variants);
    }
    int32_t starting_year = engine.year;
    int32_t activation_count = kc_policy_activation_count(model);
    int32_t opponent_activation_count = opponent_is_heuristic ? activation_count : kc_policy_activation_count(opponent_model);
    int32_t hidden_size = activation_count > opponent_activation_count ? activation_count : opponent_activation_count;
    double *hidden_cache = malloc((size_t)256 * (size_t)hidden_size * sizeof(double));
    KCPolicyActionCandidate *candidates = malloc(256 * sizeof(KCPolicyActionCandidate));
    if (!hidden_cache || !candidates) {
        free(hidden_cache);
        free(candidates);
        return 2;
    }
    int32_t guard_count = 0;
    while (engine.phase != KC_PHASE_GAME_OVER && kc_curriculum_should_continue(&engine, round_curriculum, starting_year) && guard_count < 2000) {
        guard_count++;
        if (engine.phase == KC_PHASE_REQUISITION) {
            KCAction action = { .kind = KC_ACTION_CONTINUE_AFTER_REQUISITION, .player_id = 0, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            kc_engine_apply(&engine, action);
            continue;
        }
        int32_t player_id = engine.phase == KC_PHASE_ASSIGNMENT ? engine.last_winner : engine.current_player;
        KCAction selected;
        if (player_id != model_seat && opponent_is_heuristic) {
            if (!kc_heuristic_policy_action(&engine, &selected)) {
                free(hidden_cache);
                free(candidates);
                return 3;
            }
        } else {
            KCPolicyModelBuffer selected_model = player_id == model_seat ? model : opponent_model;
            if (!kc_greedy_policy_action(&engine, player_id, selected_model, candidates, hidden_cache, &selected)) {
                free(hidden_cache);
                free(candidates);
                return 3;
            }
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(hidden_cache);
            free(candidates);
            return 10 + error;
        }
    }
    free(hidden_cache);
    free(candidates);
    if (!round_curriculum && engine.phase != KC_PHASE_GAME_OVER) {
        return 4;
    }
    if (kc_curriculum_incomplete(&engine, round_curriculum, starting_year)) {
        return 4;
    }
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        scores[player_id] = kc_final_score(&engine, player_id);
        medals[player_id] = kc_total_medals_for_player(&engine, player_id);
    }
    int32_t winner = engine.winner_id;
    if (winner < 0) {
        winner = 0;
        for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
            if (kc_player_beats_player(scores, medals, player_id, winner)) {
                winner = player_id;
            }
        }
    }
    *winner_id = winner;
    return 0;
}

KCPolicyMatchupGameResult kc_run_policy_matchup_game(
    uint64_t seed,
    KCVariants variants,
    KCPolicyModelBuffer model,
    bool model_is_heuristic,
    KCPolicyModelBuffer opponent_model,
    bool opponent_is_heuristic,
    int32_t model_seat,
    bool round_curriculum,
    int32_t round_plot_cards,
    double round_famine_rate
) {
    KCPolicyMatchupGameResult result;
    memset(&result, 0, sizeof(result));
    result.winner_id = KC_NO_PLAYER;
    if (model_seat < 0 || model_seat >= KC_PLAYER_COUNT) {
        result.status = 1;
        return result;
    }

    KCEngine engine;
    if (round_curriculum) {
        kc_engine_init_curriculum(&engine, seed, variants, round_plot_cards, round_famine_rate);
    } else {
        kc_engine_init(&engine, seed, variants);
    }
    int32_t starting_year = engine.year;
    int32_t model_activation_count = model_is_heuristic ? 0 : kc_policy_activation_count(model);
    int32_t opponent_activation_count = opponent_is_heuristic ? 0 : kc_policy_activation_count(opponent_model);
    if ((!model_is_heuristic && model_activation_count <= 0) ||
        (!opponent_is_heuristic && opponent_activation_count <= 0)) {
        result.status = 1;
        return result;
    }
    int32_t hidden_size = model_activation_count > opponent_activation_count ? model_activation_count : opponent_activation_count;
    if (hidden_size < 1) {
        hidden_size = 1;
    }
    double *hidden_cache = malloc((size_t)256 * (size_t)hidden_size * sizeof(double));
    KCPolicyActionCandidate *candidates = malloc(256 * sizeof(KCPolicyActionCandidate));
    if (!hidden_cache || !candidates) {
        free(hidden_cache);
        free(candidates);
        result.status = 2;
        return result;
    }

    int32_t guard_count = 0;
    while (engine.phase != KC_PHASE_GAME_OVER && kc_curriculum_should_continue(&engine, round_curriculum, starting_year) && guard_count < 2000) {
        guard_count++;
        if (engine.phase == KC_PHASE_REQUISITION) {
            KCAction action = { .kind = KC_ACTION_CONTINUE_AFTER_REQUISITION, .player_id = 0, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
            int32_t error = kc_engine_apply(&engine, action);
            if (error != 0) {
                free(hidden_cache);
                free(candidates);
                result.status = 10 + error;
                return result;
            }
            result.actions += 1;
            continue;
        }
        int32_t player_id = engine.phase == KC_PHASE_ASSIGNMENT ? engine.last_winner : engine.current_player;
        bool use_model = player_id == model_seat;
        bool use_heuristic = use_model ? model_is_heuristic : opponent_is_heuristic;
        KCPolicyModelBuffer selected_model = use_model ? model : opponent_model;
        KCAction selected;
        bool ok = use_heuristic
            ? kc_heuristic_policy_action(&engine, &selected)
            : kc_greedy_policy_action(&engine, player_id, selected_model, candidates, hidden_cache, &selected);
        if (!ok) {
            free(hidden_cache);
            free(candidates);
            result.status = 3;
            return result;
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(hidden_cache);
            free(candidates);
            result.status = 10 + error;
            return result;
        }
        result.actions += 1;
    }
    free(hidden_cache);
    free(candidates);
    if (!round_curriculum && engine.phase != KC_PHASE_GAME_OVER) {
        result.status = 4;
        return result;
    }
    if (kc_curriculum_incomplete(&engine, round_curriculum, starting_year)) {
        result.status = 4;
        return result;
    }

    int32_t score_sum = 0;
    int32_t winner = engine.winner_id;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        result.scores[player_id] = kc_final_score(&engine, player_id);
        result.medals[player_id] = kc_total_medals_for_player(&engine, player_id);
        score_sum += result.scores[player_id];
    }
    if (winner < 0) {
        winner = 0;
        for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
            if (kc_player_beats_player(result.scores, result.medals, player_id, winner)) {
                winner = player_id;
            }
        }
    }
    result.winner_id = winner;
    result.checksum = winner * 31 + score_sum;
    return result;
}

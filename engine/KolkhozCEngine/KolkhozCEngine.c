#include "KolkhozCEngineInternal.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

KCCard kc_no_card(void) {
    return (KCCard){ .suit = -1, .value = 0 };
}

bool kc_card_equal(KCCard a, KCCard b) {
    return a.suit == b.suit && a.value == b.value;
}

bool kc_card_is_wrecker(KCCard card) {
    return card.suit == KC_SUIT_WRECKER && card.value == KC_WRECKER_VALUE;
}

bool kc_card_valid(KCCard card) {
    return (card.suit >= 0 && card.suit < KC_SUIT_COUNT && card.value > 0) ||
        kc_card_is_wrecker(card);
}

bool kc_card_matches_suit(KCCard card, int32_t suit) {
    return suit >= 0 &&
        suit < KC_SUIT_COUNT &&
        kc_card_valid(card) &&
        (card.suit == suit || kc_card_is_wrecker(card));
}

int32_t kc_lead_suit(const KCEngine *engine) {
    if (!engine || engine->current_trick_count <= 0) {
        return KC_NO_SUIT;
    }
    KCCard lead = engine->current_trick[0].card;
    return kc_card_is_wrecker(lead) ? KC_NO_SUIT : lead.suit;
}

static void kc_process_automatic_turns(KCEngine *engine);
static int32_t kc_engine_apply_action(KCEngine *engine, KCAction action);
static bool kc_step_requisition(KCEngine *engine);
static void kc_append_exiled(KCEngine *engine, KCCard card, int32_t player_id);

static int32_t kc_single_assignment_target(const KCEngine *engine) {
    int32_t only_target = KC_NO_SUIT;
    int32_t target_count = 0;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        bool legal = false;
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (kc_card_matches_suit(engine->last_trick[i].card, suit)) {
                legal = true;
                break;
            }
        }
        if (legal) {
            only_target = suit;
            target_count++;
            if (target_count > 1) {
                return KC_NO_SUIT;
            }
        }
    }
    return target_count == 1 ? only_target : KC_NO_SUIT;
}

static void kc_prefill_single_assignment_target(KCEngine *engine) {
    int32_t target = kc_single_assignment_target(engine);
    if (target < 0) {
        return;
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        engine->pending_assignment_targets[i] = target;
    }
}

static uint64_t kc_next(KCEngine *engine) {
    if (engine->rng_state == 0) {
        engine->rng_state = 1;
    }
    engine->rng_state = engine->rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return engine->rng_state;
}

static uint64_t kc_multiply_high(uint64_t lhs, uint64_t rhs) {
    uint64_t lhs_low = (uint32_t)lhs;
    uint64_t lhs_high = lhs >> 32;
    uint64_t rhs_low = (uint32_t)rhs;
    uint64_t rhs_high = rhs >> 32;
    uint64_t low_product = lhs_low * rhs_low;
    uint64_t cross_left = lhs_low * rhs_high;
    uint64_t cross_right = lhs_high * rhs_low;
    uint64_t carry = (low_product >> 32) + (uint32_t)cross_left + (uint32_t)cross_right;
    return lhs_high * rhs_high + (cross_left >> 32) + (cross_right >> 32) + (carry >> 32);
}

static uint64_t kc_random_below(KCEngine *engine, uint64_t upper_bound) {
    return kc_multiply_high(kc_next(engine), upper_bound);
}

static double kc_uniform(KCEngine *engine) {
    return (double)(kc_next(engine) >> 11) / (double)(1ULL << 53);
}

static void kc_list_clear(KCCardList *list) {
    list->count = 0;
}

static void kc_list_append(KCCardList *list, KCCard card) {
    if (list->count < KC_MAX_CARDS) {
        list->cards[list->count++] = card;
    }
}

static int32_t kc_list_find(const KCCardList *list, KCCard card) {
    for (int32_t i = 0; i < list->count; i++) {
        if (kc_card_equal(list->cards[i], card)) {
            return i;
        }
    }
    return -1;
}

static bool kc_list_contains(const KCCardList *list, KCCard card) {
    return kc_list_find(list, card) >= 0;
}

static KCCard kc_list_remove_at(KCCardList *list, int32_t index) {
    KCCard card = list->cards[index];
    for (int32_t i = index; i + 1 < list->count; i++) {
        list->cards[i] = list->cards[i + 1];
    }
    list->count--;
    return card;
}

static KCCard kc_list_pop_last(KCCardList *list) {
    if (list->count <= 0) {
        return kc_no_card();
    }
    return list->cards[--list->count];
}

static void kc_list_append_unique(KCCardList *list, KCCard card) {
    if (!kc_list_contains(list, card)) {
        kc_list_append(list, card);
    }
}

static void kc_shuffle(KCEngine *engine, KCCardList *list) {
    if (list->count < 2) {
        return;
    }
    for (int32_t i = 0; i + 1 < list->count; i++) {
        int32_t j = i + (int32_t)kc_random_below(engine, (uint64_t)(list->count - i));
        KCCard tmp = list->cards[i];
        list->cards[i] = list->cards[j];
        list->cards[j] = tmp;
    }
}

static void kc_reset_year_work(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        engine->claimed_jobs[suit] = false;
        engine->work_hours[suit] = 0;
        kc_list_clear(&engine->job_buckets[suit]);
        for (int32_t i = 0; i < KC_MAX_CARDS; i++) {
            engine->job_bucket_tricks[suit][i] = 0;
        }
    }
}

static void kc_clear_last_swap(KCEngine *engine) {
    engine->has_last_swap = false;
    engine->last_swap_player_id = KC_NO_PLAYER;
    engine->last_swap_plot_zone = -1;
    engine->last_swap_plot_index = -1;
    engine->last_swap_hand_index = -1;
    engine->last_swap_new_plot_card = kc_no_card();
}

static int32_t kc_variant_max_years(KCVariants variants) {
    if (variants.max_years < 1) return KC_MAX_YEARS;
    if (variants.max_years > KC_MAX_YEARS) return KC_MAX_YEARS;
    return variants.max_years;
}

void kc_variants_kolkhoz(KCVariants *variants) {
    memset(variants, 0, sizeof(*variants));
    variants->deck_type = 52;
    variants->max_years = KC_MAX_YEARS;
    variants->nomenclature = false;
    variants->allow_swap = true;
    variants->hero_of_soviet_union = true;
    variants->wrecker = true;
    variants->final_year_trump = true;
    variants->pass_cards = true;
    variants->highest_cards_requisition = true;
    variants->lotto_rewards = true;
}

void kc_controllers_all_external(KCControllers *controllers) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        controllers->seats[player_id] = KC_CONTROLLER_EXTERNAL;
    }
}

void kc_controllers_default_single_player(KCControllers *controllers) {
    kc_controllers_all_external(controllers);
    for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
        controllers->seats[player_id] = KC_CONTROLLER_HEURISTIC_AI;
    }
}

void kc_controllers_set(KCControllers *controllers, int32_t player_id, int32_t controller) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return;
    }
    controllers->seats[player_id] = controller;
}

static bool kc_controller_is_external(int32_t controller) {
    return controller == KC_CONTROLLER_EXTERNAL;
}

static bool kc_controller_is_automatic(int32_t controller) {
    return controller == KC_CONTROLLER_HEURISTIC_AI;
}

bool kc_controller_is_policy(int32_t controller) {
    return controller == KC_CONTROLLER_POLICY_AI;
}

static void kc_make_players(KCEngine *engine) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        memset(player, 0, sizeof(*player));
        player->id = player_id;
        player->is_human = kc_controller_is_external(engine->controllers.seats[player_id]);
    }
}

static void kc_reveal_jobs(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        engine->has_revealed_job[suit] = false;
        engine->revealed_jobs[suit] = kc_no_card();
        if (engine->variants.deck_type == 36) {
            if (engine->job_piles[suit].count > 0) {
                engine->revealed_jobs[suit] = engine->job_piles[suit].cards[0];
                engine->has_revealed_job[suit] = true;
            }
        } else {
            KCCard card = kc_list_pop_last(&engine->job_piles[suit]);
            if (kc_card_valid(card)) {
                engine->revealed_jobs[suit] = card;
                engine->has_revealed_job[suit] = true;
            }
        }
    }
}

static bool kc_card_in_stacks(const KCPlayer *player, KCCard card) {
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->revealed_count; i++) {
            if (kc_card_equal(stack->revealed[i], card)) {
                return true;
            }
        }
        for (int32_t i = 0; i < stack->hidden_count; i++) {
            if (kc_card_equal(stack->hidden[i], card)) {
                return true;
            }
        }
    }
    return false;
}

static bool kc_is_used_worker_card(const KCEngine *engine, KCCard card) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        const KCPlayer *player = &engine->players[player_id];
        if (kc_list_contains(&player->hand, card) ||
            kc_list_contains(&player->plot_revealed, card) ||
            kc_list_contains(&player->plot_hidden, card) ||
            kc_card_in_stacks(player, card)) {
            return true;
        }
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (kc_list_contains(&engine->job_piles[suit], card) ||
            (engine->has_revealed_job[suit] && kc_card_equal(engine->revealed_jobs[suit], card)) ||
            kc_list_contains(&engine->accumulated_job_cards[suit], card) ||
            kc_list_contains(&engine->job_buckets[suit], card)) {
            return true;
        }
    }
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        if (kc_card_equal(engine->current_trick[i].card, card)) {
            return true;
        }
    }
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (kc_card_equal(engine->last_trick[i].card, card)) {
            return true;
        }
    }
    if (!engine->variants.orden_nachalniku) {
        for (int32_t year = 0; year <= KC_MAX_YEARS; year++) {
            if (kc_list_contains(&engine->exiled[year], card)) {
                return true;
            }
        }
    }
    return false;
}

static void kc_make_worker_deck(KCEngine *engine, KCCardList *deck) {
    kc_list_clear(deck);
    int32_t low_value = engine->variants.deck_type == 36 ? 6 : 1;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        for (int32_t value = low_value; value <= 13; value++) {
            KCCard card = { .suit = suit, .value = value };
            if (!kc_is_used_worker_card(engine, card)) {
                kc_list_append(deck, card);
            }
        }
    }
    if (engine->variants.wrecker) {
        KCCard wrecker = { .suit = KC_SUIT_WRECKER, .value = KC_WRECKER_VALUE };
        if (!kc_is_used_worker_card(engine, wrecker)) {
            kc_list_append(deck, wrecker);
        }
    }
    for (int32_t i = 0; i < engine->drunkard_replacements.count; i++) {
        kc_list_append_unique(deck, engine->drunkard_replacements.cards[i]);
    }
    kc_shuffle(engine, deck);
}

static void kc_deal_hands(KCEngine *engine) {
    KCCardList deck;
    kc_make_worker_deck(engine, &deck);
    int32_t cards_per_player = engine->is_famine ? 4 : 5;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        kc_list_clear(&engine->players[player_id].hand);
    }
    for (int32_t card_index = 0; card_index < cards_per_player; card_index++) {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            KCCard card = kc_list_pop_last(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&engine->players[player_id].hand, card);
            }
        }
    }
    engine->final_year_trump_card = kc_no_card();
    if (engine->year == KC_MAX_YEARS &&
        engine->variants.final_year_trump &&
        engine->variants.wrecker &&
        deck.count > 0) {
        KCCard revealed = kc_list_pop_last(&deck);
        engine->final_year_trump_card = revealed;
        engine->trump = kc_card_is_wrecker(revealed) ? KC_NO_SUIT : revealed.suit;
        kc_append_exiled(engine, revealed, KC_NO_PLAYER);
    }
}

static void kc_setup_decks(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_list_clear(&engine->job_piles[suit]);
        if (engine->variants.deck_type == 36) {
            kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = 1 });
        } else {
            int32_t fixed_rewards = engine->variants.lotto_rewards ? 4 : KC_MAX_YEARS;
            for (int32_t value = 1; value <= fixed_rewards; value++) {
                kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = value });
            }
            if (engine->variants.lotto_rewards) {
                int32_t lotto_value = 5 + (int32_t)(kc_next(engine) % 9U);
                kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = lotto_value });
            }
            kc_shuffle(engine, &engine->job_piles[suit]);
        }
    }
    kc_reveal_jobs(engine);
    engine->is_famine = engine->year == KC_MAX_YEARS;
    kc_deal_hands(engine);
}

static void kc_engine_init_with_controllers_internal(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers, bool process_automatic) {
    memset(engine, 0, sizeof(*engine));
    engine->rng_state = seed == 0 ? 1 : seed;
    variants.final_year_trump = variants.final_year_trump && variants.wrecker;
    variants.lotto_rewards = variants.lotto_rewards && variants.deck_type != 36;
    engine->variants = variants;
    engine->controllers = controllers;
    engine->year = 1;
    engine->trump = KC_NO_SUIT;
    engine->last_winner = KC_NO_PLAYER;
    engine->winner_id = KC_NO_PLAYER;
    kc_make_players(engine);
    for (int32_t player_id = 1; player_id < KC_PLAYER_COUNT; player_id++) {
        (void)kc_next(engine);
    }
    engine->lead = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->trump_selector = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->current_player = engine->trump_selector;
    engine->phase = KC_PHASE_PLANNING;
    kc_reset_year_work(engine);
    kc_setup_decks(engine);
    if (process_automatic) {
        kc_process_automatic_turns(engine);
    }
}

void kc_engine_init_with_controllers(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers) {
    kc_engine_init_with_controllers_internal(engine, seed, variants, controllers, true);
}

void kc_engine_init_with_controllers_stepwise(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers) {
    kc_engine_init_with_controllers_internal(engine, seed, variants, controllers, false);
}

void kc_engine_init(KCEngine *engine, uint64_t seed, KCVariants variants) {
    KCControllers controllers;
    kc_controllers_all_external(&controllers);
    kc_engine_init_with_controllers(engine, seed, variants, controllers);
}

KCEngine *kc_engine_alloc(void) {
    return calloc(1, sizeof(KCEngine));
}

void kc_engine_free(KCEngine *engine) {
    free(engine);
}

void kc_engine_clone(const KCEngine *source, KCEngine *out) {
    if (!source || !out) {
        return;
    }
    *out = *source;
}

static void kc_determinization_collect_list(const KCCardList *list, KCCardList *pool) {
    for (int32_t index = 0; list && index < list->count; index++) {
        kc_list_append(pool, list->cards[index]);
    }
}

static void kc_determinization_collect_stack_hidden(const KCPlotStack *stack, KCCardList *pool) {
    for (int32_t index = 0; stack && index < stack->hidden_count; index++) {
        kc_list_append(pool, stack->hidden[index]);
    }
}

static bool kc_determinization_refill_list(KCCardList *list, KCCardList *pool) {
    for (int32_t index = 0; list && index < list->count; index++) {
        KCCard card = kc_list_pop_last(pool);
        if (!kc_card_valid(card)) {
            return false;
        }
        list->cards[index] = card;
    }
    return true;
}

static bool kc_determinization_refill_stack_hidden(KCPlotStack *stack, KCCardList *pool) {
    for (int32_t index = 0; stack && index < stack->hidden_count; index++) {
        KCCard card = kc_list_pop_last(pool);
        if (!kc_card_valid(card)) {
            return false;
        }
        stack->hidden[index] = card;
    }
    return true;
}

bool kc_engine_sample_determinization(const KCEngine *source, int32_t perspective_player, uint64_t sample_seed, KCEngine *out) {
    if (!source || !out) {
        return false;
    }
    if (!kc_valid_player_id(perspective_player)) {
        perspective_player = kc_valid_player_id(source->current_player) ? source->current_player : 0;
    }

    kc_engine_clone(source, out);
    out->rng_state = sample_seed == 0 ? 1 : sample_seed;

    KCCardList private_pool;
    kc_list_clear(&private_pool);
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (player_id == perspective_player) {
            continue;
        }
        const KCPlayer *player = &source->players[player_id];
        kc_determinization_collect_list(&player->hand, &private_pool);
        kc_determinization_collect_list(&player->plot_hidden, &private_pool);
        for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
            kc_determinization_collect_stack_hidden(&player->stacks[stack_index], &private_pool);
        }
    }
    kc_shuffle(out, &private_pool);

    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (player_id == perspective_player) {
            continue;
        }
        KCPlayer *player = &out->players[player_id];
        if (!kc_determinization_refill_list(&player->hand, &private_pool) ||
            !kc_determinization_refill_list(&player->plot_hidden, &private_pool)) {
            return false;
        }
        for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
            if (!kc_determinization_refill_stack_hidden(&player->stacks[stack_index], &private_pool)) {
                return false;
            }
        }
    }
    if (private_pool.count != 0) {
        return false;
    }

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_shuffle(out, &out->job_piles[suit]);
    }
    return true;
}

bool kc_valid_player_id(int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT;
}

bool kc_valid_suit(int32_t suit) {
    return suit >= 0 && suit < KC_SUIT_COUNT;
}

static KCCard kc_card_at(const KCCardList *list, int32_t index) {
    if (!list || index < 0 || index >= list->count) {
        return kc_no_card();
    }
    return list->cards[index];
}

int32_t kc_engine_current_player(const KCEngine *engine) {
    return engine ? engine->current_player : KC_NO_PLAYER;
}

int32_t kc_engine_lead_player(const KCEngine *engine) {
    return engine ? engine->lead : KC_NO_PLAYER;
}

int32_t kc_engine_trump(const KCEngine *engine) {
    return engine ? engine->trump : KC_NO_SUIT;
}

int32_t kc_engine_trick_count(const KCEngine *engine) {
    return engine ? engine->trick_count : 0;
}

int32_t kc_engine_last_winner(const KCEngine *engine) {
    return engine ? engine->last_winner : KC_NO_PLAYER;
}

int32_t kc_engine_winner_id(const KCEngine *engine) {
    return engine ? engine->winner_id : KC_NO_PLAYER;
}

bool kc_engine_is_famine(const KCEngine *engine) {
    return engine ? engine->is_famine : false;
}

int32_t kc_player_hand_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].hand.count;
}

KCCard kc_player_hand_card(const KCEngine *engine, int32_t player_id, int32_t index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    return kc_card_at(&engine->players[player_id].hand, index);
}

int32_t kc_player_plot_revealed_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].plot_revealed.count;
}

KCCard kc_player_plot_revealed_card(const KCEngine *engine, int32_t player_id, int32_t index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    return kc_card_at(&engine->players[player_id].plot_revealed, index);
}

int32_t kc_player_plot_hidden_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].plot_hidden.count;
}

KCCard kc_player_plot_hidden_card(const KCEngine *engine, int32_t player_id, int32_t index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    return kc_card_at(&engine->players[player_id].plot_hidden, index);
}

int32_t kc_player_plot_stack_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].stack_count;
}

int32_t kc_player_plot_stack_revealed_count(const KCEngine *engine, int32_t player_id, int32_t stack_index) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return 0;
    return player->stacks[stack_index].revealed_count;
}

KCCard kc_player_plot_stack_revealed_card(const KCEngine *engine, int32_t player_id, int32_t stack_index, int32_t card_index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return kc_no_card();
    const KCPlotStack *stack = &player->stacks[stack_index];
    if (card_index < 0 || card_index >= stack->revealed_count) return kc_no_card();
    return stack->revealed[card_index];
}

int32_t kc_player_plot_stack_hidden_count(const KCEngine *engine, int32_t player_id, int32_t stack_index) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return 0;
    return player->stacks[stack_index].hidden_count;
}

KCCard kc_player_plot_stack_hidden_card(const KCEngine *engine, int32_t player_id, int32_t stack_index, int32_t card_index) {
    if (!engine || !kc_valid_player_id(player_id)) return kc_no_card();
    const KCPlayer *player = &engine->players[player_id];
    if (stack_index < 0 || stack_index >= player->stack_count) return kc_no_card();
    const KCPlotStack *stack = &player->stacks[stack_index];
    if (card_index < 0 || card_index >= stack->hidden_count) return kc_no_card();
    return stack->hidden[card_index];
}

int32_t kc_player_medals(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].medals;
}

int32_t kc_player_banked_medals(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return 0;
    return engine->players[player_id].plot_medals;
}

bool kc_player_brigade_leader(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->players[player_id].brigade_leader;
}

bool kc_player_won_trick_this_year(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->players[player_id].has_won_trick_this_year;
}

bool kc_has_revealed_job(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return false;
    return engine->has_revealed_job[suit];
}

KCCard kc_revealed_job_card(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit) || !engine->has_revealed_job[suit]) return kc_no_card();
    return engine->revealed_jobs[suit];
}

bool kc_claimed_job(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return false;
    return engine->claimed_jobs[suit];
}

int32_t kc_work_hours(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return 0;
    return engine->work_hours[suit];
}

int32_t kc_job_bucket_count(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) return 0;
    return engine->job_buckets[suit].count;
}

KCCard kc_job_bucket_card(const KCEngine *engine, int32_t suit, int32_t index) {
    if (!engine || !kc_valid_suit(suit)) return kc_no_card();
    return kc_card_at(&engine->job_buckets[suit], index);
}

int32_t kc_job_bucket_trick(const KCEngine *engine, int32_t suit, int32_t index) {
    if (!engine || !kc_valid_suit(suit) || index < 0 || index >= engine->job_buckets[suit].count) {
        return 0;
    }
    return engine->job_bucket_tricks[suit][index];
}

int32_t kc_current_trick_count(const KCEngine *engine) {
    return engine ? engine->current_trick_count : 0;
}

int32_t kc_current_trick_player(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->current_trick_count) return KC_NO_PLAYER;
    return engine->current_trick[index].player_id;
}

KCCard kc_current_trick_card(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->current_trick_count) return kc_no_card();
    return engine->current_trick[index].card;
}

int32_t kc_last_trick_count(const KCEngine *engine) {
    return engine ? engine->last_trick_count : 0;
}

int32_t kc_last_trick_player(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->last_trick_count) return KC_NO_PLAYER;
    return engine->last_trick[index].player_id;
}

KCCard kc_last_trick_card(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->last_trick_count) return kc_no_card();
    return engine->last_trick[index].card;
}

int32_t kc_pending_assignment_target(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= KC_PLAYER_COUNT) return KC_NO_SUIT;
    return engine->pending_assignment_targets[index];
}

int32_t kc_exiled_count(const KCEngine *engine, int32_t year) {
    if (!engine || year < 0 || year > KC_MAX_YEARS) return 0;
    return engine->exiled[year].count;
}

KCCard kc_exiled_card(const KCEngine *engine, int32_t year, int32_t index) {
    if (!engine || year < 0 || year > KC_MAX_YEARS) return kc_no_card();
    return kc_card_at(&engine->exiled[year], index);
}

int32_t kc_exiled_player(const KCEngine *engine, int32_t year, int32_t index) {
    if (engine == NULL || year < 0 || year > KC_MAX_YEARS ||
        index < 0 || index >= engine->exiled[year].count) return KC_NO_PLAYER;
    return engine->exiled_player_ids[year][index];
}

int32_t kc_requisition_event_count(const KCEngine *engine) {
    return engine ? engine->requisition_event_count : 0;
}

int32_t kc_requisition_event_player(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return KC_NO_PLAYER;
    return engine->requisition_events[index].player_id;
}

int32_t kc_requisition_event_suit(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return KC_NO_SUIT;
    return engine->requisition_events[index].suit;
}

KCCard kc_requisition_event_card(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return kc_no_card();
    return engine->requisition_events[index].card;
}

int32_t kc_requisition_event_message_kind(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0 || index >= engine->requisition_event_count) return 0;
    return engine->requisition_events[index].message_kind;
}

bool kc_swap_count(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->swap_count[player_id];
}

bool kc_swap_confirmed(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->swap_confirmed[player_id];
}

bool kc_pass_confirmed(const KCEngine *engine, int32_t player_id) {
    if (!engine || !kc_valid_player_id(player_id)) return false;
    return engine->pass_confirmed[player_id];
}

KCCard kc_final_year_trump_card(const KCEngine *engine) {
    return engine ? engine->final_year_trump_card : kc_no_card();
}

static KCAction kc_legal_action_at(const KCEngine *engine, int32_t index) {
    if (!engine || index < 0) return (KCAction){0};
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    if (index >= count) return (KCAction){0};
    return actions[index];
}

int32_t kc_legal_action_count(const KCEngine *engine) {
    if (!engine) return 0;
    KCAction actions[256];
    return kc_engine_legal_actions(engine, actions, 256);
}

int32_t kc_legal_action_kind_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).kind;
}

int32_t kc_legal_action_player_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).player_id;
}

int32_t kc_legal_action_suit_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).suit;
}

KCCard kc_legal_action_card_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).card;
}

KCCard kc_legal_action_hand_card_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).hand_card;
}

KCCard kc_legal_action_plot_card_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).plot_card;
}

int32_t kc_legal_action_plot_zone_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).plot_zone;
}

int32_t kc_legal_action_target_suit_at(const KCEngine *engine, int32_t index) {
    return kc_legal_action_at(engine, index).target_suit;
}

int32_t kc_engine_apply_set_trump(KCEngine *engine, int32_t player_id, int32_t suit) {
    KCAction action = { .kind = KC_ACTION_SET_TRUMP, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_play_card(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PLAY_CARD, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_pass_card(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PASS_CARD, .player_id = player_id, .card = { .suit = suit, .value = value } };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_swap(KCEngine *engine, int32_t player_id, int32_t hand_suit, int32_t hand_value, int32_t plot_suit, int32_t plot_value, int32_t plot_zone) {
    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = { .suit = hand_suit, .value = hand_value }, .plot_card = { .suit = plot_suit, .value = plot_value }, .plot_zone = plot_zone, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_assign(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value, int32_t target_suit) {
    KCAction action = { .kind = KC_ACTION_ASSIGN, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = target_suit };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_simple(KCEngine *engine, int32_t kind, int32_t player_id) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply(engine, action);
}

int32_t kc_engine_apply_set_trump_manual(KCEngine *engine, int32_t player_id, int32_t suit) {
    KCAction action = { .kind = KC_ACTION_SET_TRUMP, .player_id = player_id, .suit = suit, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_play_card_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PLAY_CARD, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_pass_card_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value) {
    KCAction action = { .kind = KC_ACTION_PASS_CARD, .player_id = player_id, .card = { .suit = suit, .value = value } };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_swap_manual(KCEngine *engine, int32_t player_id, int32_t hand_suit, int32_t hand_value, int32_t plot_suit, int32_t plot_value, int32_t plot_zone) {
    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = { .suit = hand_suit, .value = hand_value }, .plot_card = { .suit = plot_suit, .value = plot_value }, .plot_zone = plot_zone, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_assign_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value, int32_t target_suit) {
    KCAction action = { .kind = KC_ACTION_ASSIGN, .player_id = player_id, .suit = -1, .card = { .suit = suit, .value = value }, .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = target_suit };
    return kc_engine_apply_manual(engine, action);
}

int32_t kc_engine_apply_simple_manual(KCEngine *engine, int32_t kind, int32_t player_id) {
    KCAction action = { .kind = kind, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
    return kc_engine_apply_manual(engine, action);
}

static KCCard kc_draw_from(KCCardList *deck) {
    return kc_list_pop_last(deck);
}

void kc_engine_init_curriculum_rounds(KCEngine *engine, uint64_t seed, KCVariants variants, int32_t plot_cards_per_player, double final_round_famine_rate, int32_t curriculum_rounds) {
    memset(engine, 0, sizeof(*engine));
    engine->rng_state = seed == 0 ? 1 : seed;
    engine->variants = variants;
    kc_controllers_all_external(&engine->controllers);
    engine->trump = KC_NO_SUIT;
    engine->last_winner = KC_NO_PLAYER;
    engine->winner_id = KC_NO_PLAYER;
    kc_make_players(engine);

    int32_t safe_rounds = curriculum_rounds < 1 ? 1 : (curriculum_rounds > KC_MAX_YEARS ? KC_MAX_YEARS : curriculum_rounds);
    double safe_famine_rate = final_round_famine_rate < 0 ? 0 : (final_round_famine_rate > 1 ? 1 : final_round_famine_rate);
    bool final_round_famine = safe_rounds < KC_MAX_YEARS && kc_uniform(engine) < safe_famine_rate;
    int32_t latest_non_famine_start = KC_MAX_YEARS - safe_rounds;
    if (latest_non_famine_start < 1) latest_non_famine_start = 1;
    engine->year = final_round_famine
        ? KC_MAX_YEARS - safe_rounds + 1
        : 1 + (int32_t)(kc_next(engine) % (uint64_t)latest_non_famine_start);
    engine->is_famine = false;
    engine->lead = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->trump_selector = (int32_t)(kc_next(engine) % KC_PLAYER_COUNT);
    engine->current_player = engine->trump_selector;
    engine->phase = KC_PHASE_PLANNING;
    engine->trick_count = 0;
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        engine->pending_assignment_targets[i] = KC_NO_SUIT;
    }
    memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
    memset(engine->swap_count, 0, sizeof(engine->swap_count));

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        engine->claimed_jobs[suit] = false;
        engine->work_hours[suit] = (int32_t)(kc_next(engine) % 28);
        kc_list_clear(&engine->job_buckets[suit]);
        kc_list_clear(&engine->job_piles[suit]);
        for (int32_t value = 1; value <= KC_MAX_YEARS; value++) {
            kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = value });
        }
        kc_shuffle(engine, &engine->job_piles[suit]);
        engine->has_revealed_job[suit] = true;
        engine->revealed_jobs[suit] = (KCCard){ .suit = suit, .value = 1 + (int32_t)(kc_next(engine) % KC_MAX_YEARS) };
    }

    KCCardList deck;
    kc_list_clear(&deck);
    int32_t min_worker_value = variants.deck_type == 36 ? 6 : 1;
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        for (int32_t value = min_worker_value; value <= 13; value++) {
            kc_list_append(&deck, (KCCard){ .suit = suit, .value = value });
        }
    }
    kc_shuffle(engine, &deck);

    int32_t cards_per_player = 5;
    int32_t plot_limit = plot_cards_per_player < 0 ? 0 : plot_cards_per_player;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        kc_list_clear(&player->hand);
        kc_list_clear(&player->plot_revealed);
        kc_list_clear(&player->plot_hidden);
        player->stack_count = 0;
        player->brigade_leader = false;
        player->has_won_trick_this_year = kc_uniform(engine) < 0.35;
        player->medals = (int32_t)(kc_next(engine) % 3);
        player->plot_medals = 0;

        for (int32_t card_index = 0; card_index < cards_per_player; card_index++) {
            KCCard card = kc_draw_from(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&player->hand, card);
            }
        }
        int32_t remaining_players = KC_PLAYER_COUNT - player_id;
        if (remaining_players < 1) remaining_players = 1;
        int32_t plot_count = plot_limit;
        int32_t max_available = deck.count / remaining_players;
        if (plot_count > max_available) plot_count = max_available;
        int32_t revealed_count = plot_count > 0 ? (int32_t)(kc_next(engine) % (uint64_t)(plot_count + 1)) : 0;
        for (int32_t card_index = 0; card_index < revealed_count; card_index++) {
            KCCard card = kc_draw_from(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&player->plot_revealed, card);
            }
        }
        for (int32_t card_index = revealed_count; card_index < plot_count; card_index++) {
            KCCard card = kc_draw_from(&deck);
            if (kc_card_valid(card)) {
                kc_list_append(&player->plot_hidden, card);
            }
        }
    }
    kc_process_automatic_turns(engine);
}

void kc_engine_init_curriculum(KCEngine *engine, uint64_t seed, KCVariants variants, int32_t plot_cards_per_player, double second_year_famine_rate) {
    kc_engine_init_curriculum_rounds(engine, seed, variants, plot_cards_per_player, second_year_famine_rate, 2);
}

bool kc_curriculum_should_continue(const KCEngine *engine, bool curriculum, int32_t starting_year) {
    return !curriculum || engine->year < starting_year + 2;
}

bool kc_curriculum_incomplete(const KCEngine *engine, bool curriculum, int32_t starting_year) {
    return curriculum && engine->phase != KC_PHASE_GAME_OVER && engine->year < starting_year + 2;
}

static bool kc_is_active_turn(const KCEngine *engine, int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT &&
        engine->current_player == player_id;
}

static bool kc_is_active_assignment(const KCEngine *engine, int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT &&
        engine->last_winner == player_id;
}

static void kc_clear_pass(KCEngine *engine) {
    memset(engine->pass_confirmed, 0, sizeof(engine->pass_confirmed));
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        engine->pass_cards[player_id] = kc_no_card();
    }
}

static void kc_advance_after_pass(KCEngine *engine) {
    if (engine->variants.allow_swap && engine->year > 1) {
        engine->phase = KC_PHASE_SWAP;
        engine->current_player = 0;
        memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
        memset(engine->swap_count, 0, sizeof(engine->swap_count));
        kc_clear_last_swap(engine);
    } else {
        engine->phase = KC_PHASE_TRICK;
        engine->current_player = engine->lead;
    }
}

static void kc_resolve_pass(KCEngine *engine) {
    KCCard selected[KC_PLAYER_COUNT];
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        selected[player_id] = engine->pass_cards[player_id];
        int32_t index = kc_list_find(&engine->players[player_id].hand, selected[player_id]);
        if (index >= 0) {
            kc_list_remove_at(&engine->players[player_id].hand, index);
        }
    }
    bool pass_left = engine->year % 2 == 0;
    for (int32_t sender = 0; sender < KC_PLAYER_COUNT; sender++) {
        int32_t recipient = pass_left
            ? (sender + 1) % KC_PLAYER_COUNT
            : (sender + KC_PLAYER_COUNT - 1) % KC_PLAYER_COUNT;
        kc_list_append(&engine->players[recipient].hand, selected[sender]);
    }
    kc_clear_pass(engine);
    kc_advance_after_pass(engine);
}

static int32_t kc_commit_pass(KCEngine *engine, int32_t player_id, KCCard card) {
    if (!kc_valid_player_id(player_id) || engine->pass_confirmed[player_id]) {
        return KC_ERR_WRONG_PLAYER;
    }
    if (kc_list_find(&engine->players[player_id].hand, card) < 0) {
        return KC_ERR_INVALID_CARD;
    }
    engine->pass_cards[player_id] = card;
    engine->pass_confirmed[player_id] = true;
    for (int32_t candidate = 0; candidate < KC_PLAYER_COUNT; candidate++) {
        if (!engine->pass_confirmed[candidate]) {
            engine->current_player = candidate;
            return 0;
        }
    }
    kc_resolve_pass(engine);
    return 0;
}

void kc_advance_from_planning(KCEngine *engine) {
    if (engine->is_famine && !kc_card_valid(engine->final_year_trump_card)) {
        engine->trump = KC_NO_SUIT;
    } else if (engine->trump < 0) {
        engine->trump = (int32_t)(kc_next(engine) % KC_SUIT_COUNT);
    }
    if (engine->variants.pass_cards && engine->year > 1) {
        engine->phase = KC_PHASE_PASS;
        engine->current_player = 0;
        kc_clear_pass(engine);
    } else {
        kc_advance_after_pass(engine);
    }
}

static void kc_process_automatic_turns(KCEngine *engine) {
    int32_t guard_count = 0;
    while (guard_count < 200) {
        guard_count++;
        if (kc_engine_step_automatic(engine) <= 0) {
            return;
        }
    }
}

int32_t kc_engine_step_automatic(KCEngine *engine) {
    if (!engine) {
        return 0;
    }
    if (engine->phase == KC_PHASE_PLANNING && engine->is_famine) {
        kc_advance_from_planning(engine);
        return 1;
    }
    if (engine->phase == KC_PHASE_REQUISITION &&
        engine->requisition_plan_index < engine->requisition_plan_count) {
        return kc_step_requisition(engine) ? 1 : 0;
    }
    if (engine->phase == KC_PHASE_PASS) {
        int32_t player_id = engine->current_player;
        if (!kc_valid_player_id(player_id) ||
            !kc_controller_is_automatic(engine->controllers.seats[player_id]) ||
            engine->players[player_id].hand.count <= 0) {
            return 0;
        }
        KCCard selected = engine->players[player_id].hand.cards[0];
        for (int32_t i = 1; i < engine->players[player_id].hand.count; i++) {
            KCCard candidate = engine->players[player_id].hand.cards[i];
            if (candidate.value < selected.value ||
                (candidate.value == selected.value && candidate.suit < selected.suit)) {
                selected = candidate;
            }
        }
        return kc_commit_pass(engine, player_id, selected) == 0 ? 1 : -1;
    }
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_automatic(engine->controllers.seats[player_id])) {
        return 0;
    }
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    KCAction selected;
    if (!kc_choose_benchmark_action(engine, actions, count, &selected)) {
        return 0;
    }
    int32_t error = kc_engine_apply_action(engine, selected);
    return error == 0 ? 1 : -error;
}

bool kc_engine_heuristic_action(const KCEngine *engine, KCAction *selected) {
    if (!engine || !selected) {
        return false;
    }
    if (engine->phase == KC_PHASE_PASS &&
        kc_valid_player_id(engine->current_player) &&
        !kc_controller_is_external(
            engine->controllers.seats[engine->current_player]) &&
        engine->players[engine->current_player].hand.count > 0) {
        KCCard card = engine->players[engine->current_player].hand.cards[0];
        for (int32_t i = 1; i < engine->players[engine->current_player].hand.count; i++) {
            KCCard candidate = engine->players[engine->current_player].hand.cards[i];
            if (candidate.value < card.value ||
                (candidate.value == card.value && candidate.suit < card.suit)) {
                card = candidate;
            }
        }
        *selected = (KCAction){ .kind = KC_ACTION_PASS_CARD, .player_id = engine->current_player, .card = card };
        return true;
    }
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_automatic(engine->controllers.seats[player_id])) {
        return false;
    }
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    return kc_choose_benchmark_action(engine, actions, count, selected);
}

bool kc_engine_waiting_for_external_action(const KCEngine *engine) {
    int32_t player_id = kc_engine_waiting_player(engine);
    return player_id >= 0 &&
        player_id < KC_PLAYER_COUNT &&
        kc_controller_is_external(engine->controllers.seats[player_id]);
}

int32_t kc_engine_waiting_player(const KCEngine *engine) {
    switch (engine->phase) {
    case KC_PHASE_PLANNING:
    case KC_PHASE_SWAP:
    case KC_PHASE_TRICK:
        return engine->current_player;
    case KC_PHASE_PASS:
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (!engine->pass_confirmed[player_id] &&
                kc_controller_is_external(engine->controllers.seats[player_id])) {
                return player_id;
            }
        }
        return engine->current_player;
    case KC_PHASE_ASSIGNMENT:
        return engine->last_winner;
    case KC_PHASE_REQUISITION:
        return engine->requisition_plan_index < engine->requisition_plan_count
            ? KC_NO_PLAYER
            : 0;
    default:
        return KC_NO_PLAYER;
    }
}

int32_t kc_engine_phase(const KCEngine *engine) {
    return engine ? engine->phase : KC_PHASE_GAME_OVER;
}

int32_t kc_engine_year(const KCEngine *engine) {
    return engine ? engine->year : 0;
}

bool kc_is_valid_play(const KCEngine *engine, int32_t player_id, int32_t card_index) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return false;
    }
    const KCCardList *hand = &engine->players[player_id].hand;
    if (card_index < 0 || card_index >= hand->count) {
        return false;
    }
    if (engine->current_trick_count == 0) {
        return true;
    }
    int32_t lead_suit = kc_lead_suit(engine);
    bool has_lead_suit = false;
    for (int32_t i = 0; i < hand->count; i++) {
        if (kc_card_matches_suit(hand->cards[i], lead_suit)) {
            has_lead_suit = true;
            break;
        }
    }
    return !has_lead_suit || kc_card_matches_suit(hand->cards[card_index], lead_suit);
}

static int32_t kc_trick_winner(const KCEngine *engine) {
    int32_t lead_suit = kc_lead_suit(engine);
    bool has_trump = false;
    if (engine->trump >= 0) {
        for (int32_t i = 0; i < engine->current_trick_count; i++) {
            if (kc_card_matches_suit(engine->current_trick[i].card, engine->trump)) {
                has_trump = true;
                break;
            }
        }
    }
    int32_t best_player = engine->lead;
    int32_t best_value = -1;
    int32_t winning_suit = has_trump ? engine->trump : lead_suit;
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        KCCard card = engine->current_trick[i].card;
        if ((winning_suit == KC_NO_SUIT || kc_card_matches_suit(card, winning_suit)) &&
            card.value > best_value) {
            best_value = card.value;
            best_player = engine->current_trick[i].player_id;
        }
    }
    return best_player;
}

static void kc_resolve_current_trick(KCEngine *engine) {
    int32_t winner = kc_trick_winner(engine);
    engine->last_winner = winner;
    engine->last_trick_count = engine->current_trick_count;
    for (int32_t i = 0; i < engine->current_trick_count; i++) {
        engine->last_trick[i] = engine->current_trick[i];
    }
    engine->current_trick_count = 0;
    engine->trick_count += 1;
    engine->lead = winner;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        engine->players[player_id].brigade_leader = player_id == winner;
    }
    engine->players[winner].has_won_trick_this_year = true;
    engine->players[winner].medals += 1;
    engine->phase = KC_PHASE_ASSIGNMENT;
    engine->current_player = winner;
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        engine->pending_assignment_targets[i] = KC_NO_SUIT;
    }
    kc_prefill_single_assignment_target(engine);
}

static int32_t kc_play_card_index(KCEngine *engine, int32_t player_id, int32_t card_index) {
    KCCard card = kc_list_remove_at(&engine->players[player_id].hand, card_index);
    engine->current_trick[engine->current_trick_count++] = (KCTrickPlay){
        .player_id = player_id,
        .card = card
    };
    if (engine->current_trick_count == KC_PLAYER_COUNT) {
        kc_resolve_current_trick(engine);
    } else {
        engine->current_player = (player_id + 1) % KC_PLAYER_COUNT;
    }
    return 0;
}

int32_t kc_work_value(const KCEngine *engine, KCCard card) {
    if (engine->variants.nomenclature && card.value == 11 && card.suit == engine->trump) {
        return 0;
    }
    return card.value;
}

bool kc_job_contains_wrecker(const KCEngine *engine, int32_t suit) {
    if (!engine || !kc_valid_suit(suit)) {
        return false;
    }
    const KCCardList *bucket = &engine->job_buckets[suit];
    for (int32_t i = 0; i < bucket->count; i++) {
        if (kc_card_is_wrecker(bucket->cards[i])) {
            return true;
        }
    }
    return false;
}

static bool kc_card_already_exiled_this_year(const KCEngine *engine, KCCard card) {
    if (!engine || engine->year < 0 || engine->year > KC_MAX_YEARS) {
        return false;
    }
    return kc_list_contains(&engine->exiled[engine->year], card);
}

bool kc_assignment_target_legal(const KCEngine *engine, int32_t target_suit) {
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (kc_card_matches_suit(engine->last_trick[i].card, target_suit)) {
            return true;
        }
    }
    return false;
}

int32_t kc_pending_assignment_count(const KCEngine *engine) {
    int32_t count = 0;
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (engine->pending_assignment_targets[i] >= 0) {
            count++;
        }
    }
    return count;
}

static void kc_sort_cards_ascending(KCCard *cards, int32_t count) {
    for (int32_t i = 1; i < count; i++) {
        KCCard value = cards[i];
        int32_t j = i - 1;
        while (j >= 0 && cards[j].value > value.value) {
            cards[j + 1] = cards[j];
            j--;
        }
        cards[j + 1] = value;
    }
}

static void kc_claim_job_if_needed(KCEngine *engine, int32_t suit) {
    if (engine->work_hours[suit] < KC_WORK_THRESHOLD || engine->claimed_jobs[suit]) {
        return;
    }
    engine->claimed_jobs[suit] = true;
    int32_t winner = engine->last_winner;
    if (winner < 0) {
        return;
    }
    if (engine->variants.deck_type == 36 && engine->variants.orden_nachalniku) {
        KCCardList *bucket = &engine->job_buckets[suit];
        if (bucket->count <= 0 || engine->players[winner].stack_count >= KC_MAX_STACKS) {
            return;
        }
        int32_t lowest_index = 0;
        for (int32_t i = 1; i < bucket->count; i++) {
            if (bucket->cards[i].value < bucket->cards[lowest_index].value) {
                lowest_index = i;
            }
        }
        KCPlotStack *stack = &engine->players[winner].stacks[engine->players[winner].stack_count++];
        memset(stack, 0, sizeof(*stack));
        KCCard lowest = bucket->cards[lowest_index];
        stack->revealed[stack->revealed_count++] = lowest;
        KCCard hidden[KC_MAX_CARDS];
        int32_t hidden_count = 0;
        for (int32_t i = 0; i < bucket->count; i++) {
            if (i != lowest_index) {
                hidden[hidden_count++] = bucket->cards[i];
            }
        }
        kc_sort_cards_ascending(hidden, hidden_count);
        for (int32_t i = 0; i < hidden_count; i++) {
            stack->hidden[stack->hidden_count++] = hidden[i];
        }
        kc_list_clear(bucket);
    } else if (engine->variants.deck_type != 36 && !engine->variants.northern_style && engine->has_revealed_job[suit]) {
        KCCard reward = engine->revealed_jobs[suit];
        if (engine->variants.accumulate_jobs) {
            for (int32_t i = 0; i < engine->accumulated_job_cards[suit].count; i++) {
                kc_list_append(&engine->players[winner].plot_revealed, engine->accumulated_job_cards[suit].cards[i]);
            }
            kc_list_clear(&engine->accumulated_job_cards[suit]);
        }
        kc_list_append(&engine->players[winner].plot_revealed, reward);
        engine->has_revealed_job[suit] = false;
        engine->revealed_jobs[suit] = kc_no_card();
    }
}

static void kc_apply_assignments(KCEngine *engine) {
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        int32_t target_suit = engine->pending_assignment_targets[i];
        if (target_suit < 0) {
            continue;
        }
        KCCard card = engine->last_trick[i].card;
        int32_t bucket_index = engine->job_buckets[target_suit].count;
        kc_list_append(&engine->job_buckets[target_suit], card);
        if (bucket_index < KC_MAX_CARDS) {
            engine->job_bucket_tricks[target_suit][bucket_index] = engine->trick_count;
        }
        engine->work_hours[target_suit] += kc_work_value(engine, card);
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_claim_job_if_needed(engine, suit);
    }
}

static bool kc_is_year_complete(const KCEngine *engine) {
    int32_t expected_tricks = engine->is_famine ? 3 : 4;
    if (engine->trick_count >= expected_tricks) {
        return true;
    }
    bool all_one = true;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        int32_t count = engine->players[player_id].hand.count;
        if (count == 0) {
            return true;
        }
        if (count != 1) {
            all_one = false;
        }
    }
    return all_one;
}

static void kc_move_remaining_hands_to_plots(KCEngine *engine) {
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        for (int32_t i = 0; i < player->hand.count; i++) {
            kc_list_append(&player->plot_hidden, player->hand.cards[i]);
        }
        kc_list_clear(&player->hand);
    }
}

static int32_t kc_hero_player_id(const KCEngine *engine) {
    int32_t required = engine->is_famine ? 3 : 4;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (engine->players[player_id].medals == required) {
            return player_id;
        }
    }
    return KC_NO_PLAYER;
}

static void kc_append_exiled(KCEngine *engine, KCCard card, int32_t player_id) {
    KCCardList *cards = &engine->exiled[engine->year];
    if (cards->count >= KC_MAX_CARDS) return;
    engine->exiled_player_ids[engine->year][cards->count] = player_id;
    kc_list_append(cards, card);
}

static bool kc_handle_drunkard(KCEngine *engine, int32_t suit) {
    if (!engine->variants.nomenclature || engine->trump < 0) {
        return false;
    }
    KCCardList *bucket = &engine->job_buckets[suit];
    for (int32_t i = 0; i < bucket->count; i++) {
        KCCard card = bucket->cards[i];
        if (card.value == 11 && card.suit == engine->trump) {
            kc_append_exiled(engine, card, KC_NO_PLAYER);
            if (engine->has_revealed_job[suit]) {
                kc_list_append(&engine->drunkard_replacements, engine->revealed_jobs[suit]);
            }
            if (engine->requisition_event_count < KC_MAX_CARDS) {
                engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                    .player_id = KC_NO_PLAYER,
                    .suit = suit,
                    .card = card,
                    .message_kind = 3
                };
            }
            return true;
        }
    }
    return false;
}

static void kc_reveal_hidden_cards(KCEngine *engine, int32_t player_id, int32_t suit, bool reveal_all) {
    KCPlayer *player = &engine->players[player_id];
    if (reveal_all) {
        int32_t index = 0;
        while (index < player->plot_hidden.count) {
            KCCard card = player->plot_hidden.cards[index];
            if (kc_card_matches_suit(card, suit)) {
                kc_list_remove_at(&player->plot_hidden, index);
                kc_list_append(&player->plot_revealed, card);
            } else {
                index++;
            }
        }
    } else {
        int32_t best_index = -1;
        for (int32_t i = 0; i < player->plot_hidden.count; i++) {
            KCCard card = player->plot_hidden.cards[i];
            if (kc_card_matches_suit(card, suit) &&
                (best_index < 0 || card.value > player->plot_hidden.cards[best_index].value)) {
                best_index = i;
            }
        }
        if (best_index >= 0) {
            KCCard card = kc_list_remove_at(&player->plot_hidden, best_index);
            kc_list_append(&player->plot_revealed, card);
        }
    }
}

static void kc_sort_revealed_desc(KCCard *cards, int32_t count) {
    for (int32_t i = 1; i < count; i++) {
        KCCard value = cards[i];
        int32_t j = i - 1;
        while (j >= 0 && cards[j].value < value.value) {
            cards[j + 1] = cards[j];
            j--;
        }
        cards[j + 1] = value;
    }
}

static bool kc_card_matches_any_requisition_suit(
    KCCard card,
    const bool active_suits[KC_SUIT_COUNT],
    const bool vulnerable_suits[KC_SUIT_COUNT]
) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (active_suits[suit] && vulnerable_suits[suit] && kc_card_matches_suit(card, suit)) {
            return true;
        }
    }
    return false;
}

static int32_t kc_requisition_event_suit_for_card(
    KCCard card,
    const bool active_suits[KC_SUIT_COUNT],
    const bool vulnerable_suits[KC_SUIT_COUNT]
) {
    if (!kc_card_is_wrecker(card) && card.suit >= 0 && card.suit < KC_SUIT_COUNT) {
        return card.suit;
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (active_suits[suit] && vulnerable_suits[suit]) return suit;
    }
    return KC_NO_SUIT;
}

static void kc_perform_highest_cards_requisition(KCEngine *engine, int32_t hero_id) {
    bool active_suits[KC_SUIT_COUNT] = {0};
    bool informant[KC_SUIT_COUNT] = {0};
    bool party_official[KC_SUIT_COUNT] = {0};
    bool matching_found[KC_SUIT_COUNT] = {0};
    int32_t active_count = 0;

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->work_hours[suit] >= KC_WORK_THRESHOLD && !kc_job_contains_wrecker(engine, suit)) {
            continue;
        }
        if (kc_handle_drunkard(engine, suit)) {
            continue;
        }
        active_suits[suit] = true;
        active_count++;
        if (engine->variants.nomenclature && engine->trump >= 0) {
            for (int32_t i = 0; i < engine->job_buckets[suit].count; i++) {
                KCCard card = engine->job_buckets[suit].cards[i];
                informant[suit] = informant[suit] ||
                    (card.suit == engine->trump && card.value == 12);
                party_official[suit] = party_official[suit] ||
                    (card.suit == engine->trump && card.value == 13);
            }
        }
    }

    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        if (player_id == hero_id || active_count <= 0) continue;
        bool vulnerable_suits[KC_SUIT_COUNT] = {0};
        bool any_vulnerable = false;
        bool party_bonus = false;
        for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
            if (!active_suits[suit]) continue;
            vulnerable_suits[suit] = engine->variants.northern_style ||
                engine->variants.mice_variant ||
                informant[suit] ||
                hero_id >= 0 ||
                engine->players[player_id].has_won_trick_this_year;
            any_vulnerable = any_vulnerable || vulnerable_suits[suit];
            party_bonus = party_bonus || (vulnerable_suits[suit] && party_official[suit]);
            if (vulnerable_suits[suit] && (engine->variants.mice_variant || informant[suit])) {
                kc_reveal_hidden_cards(engine, player_id, suit, true);
            }
        }
        if (!any_vulnerable) continue;

        KCCard candidates[KC_MAX_CARDS];
        int32_t candidate_count = 0;
        KCPlayer *player = &engine->players[player_id];
        for (int32_t i = 0; i < player->plot_revealed.count; i++) {
            KCCard card = player->plot_revealed.cards[i];
            if (kc_card_matches_any_requisition_suit(card, active_suits, vulnerable_suits) &&
                !kc_card_already_exiled_this_year(engine, card)) {
                candidates[candidate_count++] = card;
                for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                    if (active_suits[suit] && vulnerable_suits[suit] && kc_card_matches_suit(card, suit)) {
                        matching_found[suit] = true;
                    }
                }
            }
        }
        for (int32_t i = 0; i < player->plot_hidden.count; i++) {
            KCCard card = player->plot_hidden.cards[i];
            if (kc_card_matches_any_requisition_suit(card, active_suits, vulnerable_suits) &&
                !kc_card_already_exiled_this_year(engine, card)) {
                candidates[candidate_count++] = card;
                for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                    if (active_suits[suit] && vulnerable_suits[suit] && kc_card_matches_suit(card, suit)) {
                        matching_found[suit] = true;
                    }
                }
            }
        }
        kc_sort_revealed_desc(candidates, candidate_count);
        int32_t quota = active_count + (party_bonus ? 1 : 0);
        for (int32_t i = 0; i < candidate_count && i < quota; i++) {
            KCCard card = candidates[i];
            int32_t hidden_index = kc_list_find(&player->plot_hidden, card);
            if (hidden_index >= 0) {
                kc_list_remove_at(&player->plot_hidden, hidden_index);
                kc_list_append(&player->plot_revealed, card);
            }
            int32_t event_suit = kc_requisition_event_suit_for_card(
                card, active_suits, vulnerable_suits
            );
            kc_append_exiled(engine, card, player_id);
            if (engine->requisition_event_count < KC_MAX_CARDS) {
                engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                    .player_id = player_id,
                    .suit = event_suit,
                    .card = card,
                    .message_kind = 1
                };
            }
        }
    }

    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (active_suits[suit] && !matching_found[suit] &&
            engine->requisition_event_count < KC_MAX_CARDS) {
            engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                .player_id = KC_NO_PLAYER,
                .suit = suit,
                .card = kc_no_card(),
                .message_kind = 2
            };
        }
    }
}

static void kc_perform_requisition_batch(KCEngine *engine) {
    engine->phase = KC_PHASE_REQUISITION;
    engine->current_player = 0;
    engine->requisition_event_count = 0;
    int32_t hero_id = engine->variants.hero_of_soviet_union ? kc_hero_player_id(engine) : KC_NO_PLAYER;
    if (hero_id >= 0 && engine->requisition_event_count < KC_MAX_CARDS) {
        engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
            .player_id = hero_id,
            .suit = 0,
            .card = kc_no_card(),
            .message_kind = 4
        };
    }
    if (engine->variants.highest_cards_requisition) {
        kc_perform_highest_cards_requisition(engine, hero_id);
        return;
    }
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->work_hours[suit] >= KC_WORK_THRESHOLD && !kc_job_contains_wrecker(engine, suit)) {
            continue;
        }
        if (kc_handle_drunkard(engine, suit)) {
            continue;
        }
        bool informant = false;
        bool party_official = false;
        if (engine->variants.nomenclature && engine->trump >= 0) {
            for (int32_t i = 0; i < engine->job_buckets[suit].count; i++) {
                KCCard card = engine->job_buckets[suit].cards[i];
                if (card.suit == engine->trump && card.value == 12) {
                    informant = true;
                }
                if (card.suit == engine->trump && card.value == 13) {
                    party_official = true;
                }
            }
        }
        bool exiled_for_suit = false;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (player_id == hero_id) {
                continue;
            }
            bool vulnerable = engine->variants.northern_style ||
                engine->variants.mice_variant ||
                informant ||
                hero_id >= 0 ||
                engine->players[player_id].has_won_trick_this_year;
            if (!vulnerable) {
                continue;
            }
            kc_reveal_hidden_cards(engine, player_id, suit, engine->variants.mice_variant || informant);
            KCCard revealed[KC_MAX_CARDS];
            int32_t revealed_count = 0;
            for (int32_t i = 0; i < engine->players[player_id].plot_revealed.count; i++) {
                KCCard card = engine->players[player_id].plot_revealed.cards[i];
                if (kc_card_matches_suit(card, suit) &&
                    !kc_card_already_exiled_this_year(engine, card)) {
                    revealed[revealed_count++] = card;
                }
            }
            kc_sort_revealed_desc(revealed, revealed_count);
            int32_t limit = party_official ? 2 : 1;
            for (int32_t i = 0; i < revealed_count && i < limit; i++) {
                kc_append_exiled(engine, revealed[i], player_id);
                if (engine->requisition_event_count < KC_MAX_CARDS) {
                    engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                        .player_id = player_id,
                        .suit = suit,
                        .card = revealed[i],
                        .message_kind = 1
                    };
                }
                exiled_for_suit = true;
            }
        }
        if (!exiled_for_suit && engine->requisition_event_count < KC_MAX_CARDS) {
            engine->requisition_events[engine->requisition_event_count++] = (KCRequisitionEvent){
                .player_id = KC_NO_PLAYER,
                .suit = suit,
                .card = kc_no_card(),
                .message_kind = 2
            };
        }
    }
}

static bool kc_requisition_reveal_all(const KCEngine *engine, int32_t suit) {
    if (engine->variants.mice_variant) return true;
    if (!engine->variants.nomenclature || engine->trump < 0) return false;
    for (int32_t i = 0; i < engine->job_buckets[suit].count; i++) {
        KCCard card = engine->job_buckets[suit].cards[i];
        if (card.suit == engine->trump && card.value == 12) return true;
    }
    return false;
}

static bool kc_step_requisition(KCEngine *engine) {
    if (!engine || engine->phase != KC_PHASE_REQUISITION ||
        engine->requisition_plan_index >= engine->requisition_plan_count) {
        return false;
    }
    int32_t event_index = engine->requisition_plan_index++;
    KCRequisitionEvent event = engine->requisition_plan[event_index];
    if (event.message_kind == 1 && event.player_id >= 0 && event.player_id < KC_PLAYER_COUNT) {
        bool continues_player_suit = false;
        if (event_index > 0) {
            KCRequisitionEvent previous = engine->requisition_plan[event_index - 1];
            continues_player_suit = previous.message_kind == 1 &&
                previous.player_id == event.player_id && previous.suit == event.suit;
        }
        if (!continues_player_suit) {
            kc_reveal_hidden_cards(
                engine,
                event.player_id,
                event.suit,
                kc_requisition_reveal_all(engine, event.suit)
            );
        }
        kc_append_exiled(engine, event.card, event.player_id);
    } else if (event.message_kind == 3) {
        kc_append_exiled(engine, event.card, KC_NO_PLAYER);
        if (event.suit >= 0 && event.suit < KC_SUIT_COUNT && engine->has_revealed_job[event.suit]) {
            kc_list_append(&engine->drunkard_replacements, engine->revealed_jobs[event.suit]);
        }
    }
    if (engine->requisition_event_count < KC_MAX_CARDS) {
        engine->requisition_events[engine->requisition_event_count++] = event;
    }
    return true;
}

static void kc_perform_requisition(KCEngine *engine) {
    KCEngine resolved = *engine;
    kc_perform_requisition_batch(&resolved);
    engine->phase = KC_PHASE_REQUISITION;
    engine->current_player = 0;
    engine->requisition_event_count = 0;
    engine->requisition_plan_count = resolved.requisition_event_count;
    engine->requisition_plan_index = 0;
    for (int32_t i = 0; i < resolved.requisition_event_count; i++) {
        engine->requisition_plan[i] = resolved.requisition_events[i];
    }
}

static void kc_advance_after_assignments(KCEngine *engine) {
    if (kc_is_year_complete(engine)) {
        kc_move_remaining_hands_to_plots(engine);
        kc_perform_requisition(engine);
    } else {
        engine->phase = KC_PHASE_TRICK;
        engine->current_player = engine->lead;
    }
}

static void kc_remove_exiled_cards(KCEngine *engine) {
    KCCardList *cards = &engine->exiled[engine->year];
    for (int32_t exiled_index = 0; exiled_index < cards->count; exiled_index++) {
        KCCard card = cards->cards[exiled_index];
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            int32_t index = kc_list_find(&engine->players[player_id].plot_revealed, card);
            if (index >= 0) {
                kc_list_remove_at(&engine->players[player_id].plot_revealed, index);
                break;
            }
        }
    }
}

int32_t kc_visible_score(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    const KCPlayer *player = &engine->players[player_id];
    int32_t score = 0;
    for (int32_t i = 0; i < player->plot_revealed.count; i++) {
        score += player->plot_revealed.cards[i].value;
    }
    for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
        const KCPlotStack *stack = &player->stacks[stack_index];
        for (int32_t i = 0; i < stack->revealed_count; i++) {
            score += stack->revealed[i].value;
        }
    }
    if (engine->variants.medals_count) {
        score += player->plot_medals + player->medals;
    }
    return score;
}

int32_t kc_final_score(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    int32_t score = kc_visible_score(engine, player_id);
    const KCPlayer *player = &engine->players[player_id];
    for (int32_t i = 0; i < player->plot_hidden.count; i++) {
        score += player->plot_hidden.cards[i].value;
    }
    return score;
}

static void kc_finish_game(KCEngine *engine) {
    int32_t winner = 0;
    int32_t best_score = -1;
    int32_t best_medals = -1;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        int32_t score = kc_final_score(engine, player_id);
        int32_t medals = engine->players[player_id].plot_medals + engine->players[player_id].medals;
        engine->game_scores[player_id] = score;
        if (score > best_score ||
            (score == best_score && medals > best_medals) ||
            (score == best_score && medals == best_medals && player_id > winner)) {
            best_score = score;
            best_medals = medals;
            winner = player_id;
        }
    }
    engine->winner_id = winner;
    engine->phase = KC_PHASE_GAME_OVER;
    engine->current_player = 0;
}

static void kc_transition_to_next_year(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        if (engine->variants.deck_type == 36 || engine->variants.northern_style) {
            continue;
        }
        if (engine->has_revealed_job[suit]) {
            if (engine->variants.accumulate_jobs) {
                kc_list_append(&engine->accumulated_job_cards[suit], engine->revealed_jobs[suit]);
            } else {
                kc_append_exiled(engine, engine->revealed_jobs[suit], KC_NO_PLAYER);
            }
        }
    }
    if (engine->year >= kc_variant_max_years(engine->variants)) {
        kc_finish_game(engine);
        return;
    }
    engine->year += 1;
    engine->trick_count = 0;
    engine->current_trick_count = 0;
    engine->last_trick_count = 0;
    engine->last_winner = KC_NO_PLAYER;
    engine->trump = KC_NO_SUIT;
    engine->requisition_event_count = 0;
    engine->requisition_plan_count = 0;
    engine->requisition_plan_index = 0;
    memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
    memset(engine->swap_count, 0, sizeof(engine->swap_count));
    kc_clear_last_swap(engine);
    kc_reset_year_work(engine);
    if (engine->variants.orden_nachalniku && engine->variants.deck_type == 36) {
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            KCPlayer *player = &engine->players[player_id];
            for (int32_t stack_index = 0; stack_index < player->stack_count; stack_index++) {
                KCPlotStack *stack = &player->stacks[stack_index];
                for (int32_t i = 0; i < stack->revealed_count; i++) {
                    kc_list_append(&player->plot_revealed, stack->revealed[i]);
                }
            }
            player->stack_count = 0;
        }
    }
    kc_reveal_jobs(engine);
    engine->is_famine = engine->year == KC_MAX_YEARS;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        KCPlayer *player = &engine->players[player_id];
        player->plot_medals += player->medals;
        player->medals = 0;
        player->has_won_trick_this_year = false;
        player->brigade_leader = false;
    }
    engine->trump_selector = (engine->trump_selector + 1) % KC_PLAYER_COUNT;
    engine->current_player = engine->trump_selector;
    engine->phase = KC_PHASE_PLANNING;
    kc_deal_hands(engine);
}

static int32_t kc_swap_card(KCEngine *engine, int32_t player_id, KCCard hand_card, KCCard plot_card, int32_t zone) {
    int32_t hand_index = kc_list_find(&engine->players[player_id].hand, hand_card);
    if (hand_index < 0) {
        return KC_ERR_INVALID_CARD;
    }
    KCCardList *plot = zone == KC_ZONE_REVEALED ?
        &engine->players[player_id].plot_revealed :
        &engine->players[player_id].plot_hidden;
    int32_t plot_index = kc_list_find(plot, plot_card);
    if (plot_index < 0) {
        return KC_ERR_INVALID_CARD;
    }
    plot->cards[plot_index] = hand_card;
    engine->players[player_id].hand.cards[hand_index] = plot_card;
    engine->swap_count[player_id] = true;
    engine->has_last_swap = true;
    engine->last_swap_player_id = player_id;
    engine->last_swap_plot_zone = zone;
    engine->last_swap_plot_index = plot_index;
    engine->last_swap_hand_index = hand_index;
    engine->last_swap_new_plot_card = hand_card;
    return 0;
}

static int32_t kc_undo_swap(KCEngine *engine, int32_t player_id) {
    if (!engine->has_last_swap ||
        engine->last_swap_player_id != player_id ||
        !engine->swap_count[player_id] ||
        engine->last_swap_hand_index < 0 ||
        engine->last_swap_hand_index >= engine->players[player_id].hand.count) {
        return KC_ERR_INVALID_CARD;
    }
    KCCardList *plot = engine->last_swap_plot_zone == KC_ZONE_REVEALED ?
        &engine->players[player_id].plot_revealed :
        &engine->players[player_id].plot_hidden;
    if (engine->last_swap_plot_index < 0 || engine->last_swap_plot_index >= plot->count) {
        return KC_ERR_INVALID_CARD;
    }
    KCCard temporary = plot->cards[engine->last_swap_plot_index];
    plot->cards[engine->last_swap_plot_index] = engine->players[player_id].hand.cards[engine->last_swap_hand_index];
    engine->players[player_id].hand.cards[engine->last_swap_hand_index] = temporary;
    engine->swap_count[player_id] = false;
    kc_clear_last_swap(engine);
    return 0;
}

static void kc_confirm_swap(KCEngine *engine, int32_t player_id) {
    engine->swap_confirmed[player_id] = true;
    int32_t confirmed = 0;
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
        confirmed += engine->swap_confirmed[i] ? 1 : 0;
    }
    if (confirmed >= KC_PLAYER_COUNT) {
        engine->phase = KC_PHASE_TRICK;
        engine->current_player = engine->lead;
        memset(engine->swap_confirmed, 0, sizeof(engine->swap_confirmed));
        memset(engine->swap_count, 0, sizeof(engine->swap_count));
        kc_clear_last_swap(engine);
        return;
    }
    int32_t next = player_id + 1;
    engine->current_player = next < KC_PLAYER_COUNT ? next : KC_PLAYER_COUNT - 1;
}

static int32_t kc_engine_apply_action(KCEngine *engine, KCAction action) {
    int32_t player_id = action.player_id;
    switch (action.kind) {
    case KC_ACTION_SET_TRUMP:
        if (engine->phase != KC_PHASE_PLANNING) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (action.suit < 0 || action.suit >= KC_SUIT_COUNT) {
            return KC_ERR_INVALID_CARD;
        }
        engine->trump = action.suit;
        kc_advance_from_planning(engine);
        return 0;

    case KC_ACTION_SWAP:
        if (engine->phase != KC_PHASE_SWAP) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (engine->swap_count[player_id]) {
            return KC_ERR_INVALID_CARD;
        }
        return kc_swap_card(engine, player_id, action.hand_card, action.plot_card, action.plot_zone);

    case KC_ACTION_CONFIRM_SWAP:
        if (engine->phase != KC_PHASE_SWAP) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        kc_confirm_swap(engine, player_id);
        return 0;

    case KC_ACTION_UNDO_SWAP:
        if (engine->phase != KC_PHASE_SWAP) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        return kc_undo_swap(engine, player_id);

    case KC_ACTION_PASS_CARD:
        if (engine->phase != KC_PHASE_PASS) {
            return KC_ERR_WRONG_PHASE;
        }
        return kc_commit_pass(engine, player_id, action.card);

    case KC_ACTION_PLAY_CARD: {
        if (engine->phase != KC_PHASE_TRICK) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_turn(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        int32_t card_index = kc_list_find(&engine->players[player_id].hand, action.card);
        if (!kc_is_valid_play(engine, player_id, card_index)) {
            return KC_ERR_INVALID_CARD;
        }
        return kc_play_card_index(engine, player_id, card_index);
    }

    case KC_ACTION_ASSIGN: {
        if (engine->phase != KC_PHASE_ASSIGNMENT) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_assignment(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (!kc_assignment_target_legal(engine, action.target_suit)) {
            return KC_ERR_INVALID_ASSIGNMENT;
        }
        for (int32_t i = 0; i < engine->last_trick_count; i++) {
            if (engine->pending_assignment_targets[i] < 0 && kc_card_equal(engine->last_trick[i].card, action.card)) {
                engine->pending_assignment_targets[i] = action.target_suit;
                return 0;
            }
        }
        return KC_ERR_INVALID_ASSIGNMENT;
    }

    case KC_ACTION_SUBMIT_ASSIGNMENTS:
        if (engine->phase != KC_PHASE_ASSIGNMENT) {
            return KC_ERR_WRONG_PHASE;
        }
        if (!kc_is_active_assignment(engine, player_id)) {
            return KC_ERR_WRONG_PLAYER;
        }
        if (kc_pending_assignment_count(engine) != engine->last_trick_count) {
            return KC_ERR_INVALID_ASSIGNMENT;
        }
        kc_apply_assignments(engine);
        for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) {
            engine->pending_assignment_targets[i] = KC_NO_SUIT;
        }
        kc_advance_after_assignments(engine);
        return 0;

    case KC_ACTION_CONTINUE_AFTER_REQUISITION:
        if (engine->phase != KC_PHASE_REQUISITION) {
            return 0;
        }
        if (engine->requisition_plan_index < engine->requisition_plan_count) {
            return KC_ERR_WRONG_PHASE;
        }
        kc_remove_exiled_cards(engine);
        kc_transition_to_next_year(engine);
        return 0;

    default:
        return KC_ERR_INVALID_CARD;
    }
}

int32_t kc_engine_apply(KCEngine *engine, KCAction action) {
    int32_t error = kc_engine_apply_action(engine, action);
    if (error == 0) {
        kc_process_automatic_turns(engine);
    }
    return error;
}

int32_t kc_engine_apply_manual(KCEngine *engine, KCAction action) {
    return kc_engine_apply_action(engine, action);
}

static void kc_add_action(KCAction *actions, int32_t max_actions, int32_t *count, KCAction action) {
    if (*count < max_actions) {
        actions[*count] = action;
    }
    *count += 1;
}

int32_t kc_engine_legal_actions(const KCEngine *engine, KCAction *actions, int32_t max_actions) {
    int32_t count = 0;
    switch (engine->phase) {
    case KC_PHASE_PLANNING:
        if (!engine->is_famine) {
            for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                KCAction action = {0};
                action.kind = KC_ACTION_SET_TRUMP;
                action.player_id = engine->current_player;
                action.suit = suit;
                action.card = kc_no_card();
                action.hand_card = kc_no_card();
                action.plot_card = kc_no_card();
                action.plot_zone = -1;
                action.target_suit = -1;
                kc_add_action(actions, max_actions, &count, action);
            }
        }
        break;

    case KC_PHASE_SWAP: {
        int32_t player_id = engine->current_player;
        if (!engine->swap_count[player_id]) {
            const KCPlayer *player = &engine->players[player_id];
            for (int32_t hand_index = 0; hand_index < player->hand.count; hand_index++) {
                for (int32_t plot_index = 0; plot_index < player->plot_hidden.count; plot_index++) {
                    KCAction action = {0};
                    action.kind = KC_ACTION_SWAP;
                    action.player_id = player_id;
                    action.card = kc_no_card();
                    action.hand_card = player->hand.cards[hand_index];
                    action.plot_card = player->plot_hidden.cards[plot_index];
                    action.plot_zone = KC_ZONE_HIDDEN;
                    action.suit = -1;
                    action.target_suit = -1;
                    kc_add_action(actions, max_actions, &count, action);
                }
                for (int32_t plot_index = 0; plot_index < player->plot_revealed.count; plot_index++) {
                    KCAction action = {0};
                    action.kind = KC_ACTION_SWAP;
                    action.player_id = player_id;
                    action.card = kc_no_card();
                    action.hand_card = player->hand.cards[hand_index];
                    action.plot_card = player->plot_revealed.cards[plot_index];
                    action.plot_zone = KC_ZONE_REVEALED;
                    action.suit = -1;
                    action.target_suit = -1;
                    kc_add_action(actions, max_actions, &count, action);
                }
            }
        } else if (engine->has_last_swap && engine->last_swap_player_id == player_id) {
            KCAction action = {0};
            action.kind = KC_ACTION_UNDO_SWAP;
            action.player_id = player_id;
            action.suit = -1;
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        }
        KCAction action = {0};
        action.kind = KC_ACTION_CONFIRM_SWAP;
        action.player_id = player_id;
        action.suit = -1;
        action.card = kc_no_card();
        action.hand_card = kc_no_card();
        action.plot_card = kc_no_card();
        action.plot_zone = -1;
        action.target_suit = -1;
        kc_add_action(actions, max_actions, &count, action);
        break;
    }

    case KC_PHASE_PASS:
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            if (engine->pass_confirmed[player_id]) {
                continue;
            }
            const KCCardList *hand = &engine->players[player_id].hand;
            for (int32_t card_index = 0; card_index < hand->count; card_index++) {
                KCAction action = {0};
                action.kind = KC_ACTION_PASS_CARD;
                action.player_id = player_id;
                action.card = hand->cards[card_index];
                action.suit = -1;
                action.hand_card = kc_no_card();
                action.plot_card = kc_no_card();
                action.plot_zone = -1;
                action.target_suit = -1;
                kc_add_action(actions, max_actions, &count, action);
            }
        }
        break;

    case KC_PHASE_TRICK: {
        int32_t player_id = engine->current_player;
        const KCCardList *hand = &engine->players[player_id].hand;
        for (int32_t card_index = 0; card_index < hand->count; card_index++) {
            if (kc_is_valid_play(engine, player_id, card_index)) {
                KCAction action = {0};
                action.kind = KC_ACTION_PLAY_CARD;
                action.player_id = player_id;
                action.card = hand->cards[card_index];
                action.suit = -1;
                action.hand_card = kc_no_card();
                action.plot_card = kc_no_card();
                action.plot_zone = -1;
                action.target_suit = -1;
                kc_add_action(actions, max_actions, &count, action);
            }
        }
        break;
    }

    case KC_PHASE_ASSIGNMENT: {
        int32_t winner = engine->last_winner;
        if (kc_pending_assignment_count(engine) >= engine->last_trick_count) {
            KCAction action = {0};
            action.kind = KC_ACTION_SUBMIT_ASSIGNMENTS;
            action.player_id = winner;
            action.suit = -1;
            action.card = kc_no_card();
            action.hand_card = kc_no_card();
            action.plot_card = kc_no_card();
            action.plot_zone = -1;
            action.target_suit = -1;
            kc_add_action(actions, max_actions, &count, action);
        } else {
            for (int32_t play_index = 0; play_index < engine->last_trick_count; play_index++) {
                if (engine->pending_assignment_targets[play_index] >= 0) {
                    continue;
                }
                for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
                    if (kc_assignment_target_legal(engine, suit)) {
                        KCAction action = {0};
                        action.kind = KC_ACTION_ASSIGN;
                        action.player_id = winner;
                        action.card = engine->last_trick[play_index].card;
                        action.target_suit = suit;
                        action.suit = -1;
                        action.hand_card = kc_no_card();
                        action.plot_card = kc_no_card();
                        action.plot_zone = -1;
                        kc_add_action(actions, max_actions, &count, action);
                    }
                }
            }
        }
        break;
    }

    case KC_PHASE_REQUISITION: {
        if (engine->requisition_plan_index < engine->requisition_plan_count) {
            break;
        }
        KCAction action = {0};
        action.kind = KC_ACTION_CONTINUE_AFTER_REQUISITION;
        action.player_id = 0;
        action.suit = -1;
        action.card = kc_no_card();
        action.hand_card = kc_no_card();
        action.plot_card = kc_no_card();
        action.plot_zone = -1;
        action.target_suit = -1;
        kc_add_action(actions, max_actions, &count, action);
        break;
    }

    default:
        break;
    }
    return count;
}

static int32_t kc_action_kind_order(KCAction action) {
    return action.kind;
}

bool kc_action_less(KCAction lhs, KCAction rhs) {
    int32_t left_key[] = {
        kc_action_kind_order(lhs),
        lhs.player_id,
        lhs.suit,
        lhs.card.suit,
        lhs.card.value,
        lhs.hand_card.suit,
        lhs.hand_card.value,
        lhs.plot_card.suit,
        lhs.plot_card.value,
        lhs.plot_zone,
        lhs.target_suit
    };
    int32_t right_key[] = {
        kc_action_kind_order(rhs),
        rhs.player_id,
        rhs.suit,
        rhs.card.suit,
        rhs.card.value,
        rhs.hand_card.suit,
        rhs.hand_card.value,
        rhs.plot_card.suit,
        rhs.plot_card.value,
        rhs.plot_zone,
        rhs.target_suit
    };
    for (int32_t i = 0; i < 11; i++) {
        if (left_key[i] != right_key[i]) {
            return left_key[i] < right_key[i];
        }
    }
    return false;
}

KCGameRunResult kc_run_benchmark_game(uint64_t seed, KCVariants variants) {
    KCEngine engine;
    kc_engine_init(&engine, seed, variants);
    KCGameRunResult result = {0};
    while (engine.phase != KC_PHASE_GAME_OVER && result.actions < 1000) {
        KCAction actions[256];
        int32_t count = kc_engine_legal_actions(&engine, actions, 256);
        KCAction selected;
        if (!kc_choose_benchmark_action(&engine, actions, count, &selected)) {
            result.checksum = -999999;
            return result;
        }
        int32_t error = kc_engine_apply(&engine, selected);
        if (error != 0) {
            result.checksum = -error;
            return result;
        }
        result.actions += 1;
    }
    int32_t score_sum = 0;
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        score_sum += kc_final_score(&engine, player_id);
    }
    result.checksum = engine.winner_id * 31 + score_sum;
    return result;
}

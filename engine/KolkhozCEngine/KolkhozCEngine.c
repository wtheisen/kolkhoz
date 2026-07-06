#include "KolkhozCEngine.h"

#include <math.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#define KC_VALUE_INPUT_SIZE 64
#define KC_MAX_POLICY_DECISIONS 256
#define KC_MAX_POLICY_ACTIVATIONS 4096

enum {
    KC_WORK_THRESHOLD = 40,
    KC_WRECKER_VALUE = 14,
    KC_NO_SUIT = -1,
    KC_NO_PLAYER = -1,
    KC_ZONE_HIDDEN = 0,
    KC_ZONE_REVEALED = 1,
    KC_ERR_WRONG_PHASE = 1,
    KC_ERR_WRONG_PLAYER = 2,
    KC_ERR_INVALID_CARD = 3,
    KC_ERR_INVALID_ASSIGNMENT = 4
};

static KCCard kc_no_card(void) {
    return (KCCard){ .suit = -1, .value = 0 };
}

static bool kc_card_equal(KCCard a, KCCard b) {
    return a.suit == b.suit && a.value == b.value;
}

static bool kc_card_is_wrecker(KCCard card) {
    return card.suit == KC_SUIT_WRECKER && card.value == KC_WRECKER_VALUE;
}

static bool kc_card_valid(KCCard card) {
    return (card.suit >= 0 && card.suit < KC_SUIT_COUNT && card.value > 0) ||
        kc_card_is_wrecker(card);
}

static bool kc_card_matches_suit(KCCard card, int32_t suit) {
    return suit >= 0 &&
        suit < KC_SUIT_COUNT &&
        kc_card_valid(card) &&
        (card.suit == suit || kc_card_is_wrecker(card));
}

static double kc_card_value_feature(KCCard card) {
    return kc_card_valid(card) ? (double)card.value / (double)KC_WRECKER_VALUE : 0.0;
}

static double kc_raw_card_value_feature(int32_t value) {
    return value > 0 ? (double)value / (double)KC_WRECKER_VALUE : 0.0;
}

static int32_t kc_lead_suit(const KCEngine *engine) {
    if (!engine || engine->current_trick_count <= 0) {
        return KC_NO_SUIT;
    }
    KCCard lead = engine->current_trick[0].card;
    return kc_card_is_wrecker(lead) ? KC_NO_SUIT : lead.suit;
}

static void kc_process_automatic_turns(KCEngine *engine);
static int32_t kc_engine_apply_action(KCEngine *engine, KCAction action);
static bool kc_choose_benchmark_action(const KCAction *actions, int32_t count, KCAction *selected);
static bool kc_valid_player_id(int32_t player_id);

static uint64_t kc_next(KCEngine *engine) {
    if (engine->rng_state == 0) {
        engine->rng_state = 1;
    }
    engine->rng_state = engine->rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return engine->rng_state;
}

static uint64_t kc_random_below(KCEngine *engine, uint64_t upper_bound) {
    return (uint64_t)(((__uint128_t)kc_next(engine) * upper_bound) >> 64);
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

void kc_variants_kolkhoz(KCVariants *variants) {
    memset(variants, 0, sizeof(*variants));
    variants->deck_type = 52;
    variants->nomenclature = false;
    variants->allow_swap = true;
    variants->hero_of_soviet_union = true;
    variants->wrecker = true;
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

static bool kc_controller_is_policy(int32_t controller) {
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
}

static void kc_setup_decks(KCEngine *engine) {
    for (int32_t suit = 0; suit < KC_SUIT_COUNT; suit++) {
        kc_list_clear(&engine->job_piles[suit]);
        if (engine->variants.deck_type == 36) {
            kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = 1 });
        } else {
            for (int32_t value = 1; value <= KC_MAX_YEARS; value++) {
                kc_list_append(&engine->job_piles[suit], (KCCard){ .suit = suit, .value = value });
            }
            kc_shuffle(engine, &engine->job_piles[suit]);
        }
    }
    kc_reveal_jobs(engine);
    engine->is_famine = engine->year == KC_MAX_YEARS;
    kc_deal_hands(engine);
}

void kc_engine_init_with_controllers(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers) {
    memset(engine, 0, sizeof(*engine));
    engine->rng_state = seed == 0 ? 1 : seed;
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
    kc_process_automatic_turns(engine);
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

static bool kc_valid_player_id(int32_t player_id) {
    return player_id >= 0 && player_id < KC_PLAYER_COUNT;
}

static bool kc_valid_suit(int32_t suit) {
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

static bool kc_curriculum_should_continue(const KCEngine *engine, bool curriculum, int32_t starting_year) {
    return !curriculum || engine->year < starting_year + 2;
}

static bool kc_curriculum_incomplete(const KCEngine *engine, bool curriculum, int32_t starting_year) {
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

static void kc_advance_from_planning(KCEngine *engine) {
    if (engine->is_famine) {
        engine->trump = KC_NO_SUIT;
    } else if (engine->trump < 0) {
        engine->trump = (int32_t)(kc_next(engine) % KC_SUIT_COUNT);
    }
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
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_automatic(engine->controllers.seats[player_id])) {
        return 0;
    }
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    KCAction selected;
    if (!kc_choose_benchmark_action(actions, count, &selected)) {
        return 0;
    }
    int32_t error = kc_engine_apply_action(engine, selected);
    return error == 0 ? 1 : -error;
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
    case KC_PHASE_ASSIGNMENT:
        return engine->last_winner;
    case KC_PHASE_REQUISITION:
        return 0;
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

static bool kc_is_valid_play(const KCEngine *engine, int32_t player_id, int32_t card_index) {
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

static int32_t kc_work_value(const KCEngine *engine, KCCard card) {
    if (engine->variants.nomenclature && card.value == 11 && card.suit == engine->trump) {
        return 0;
    }
    return card.value;
}

static bool kc_job_contains_wrecker(const KCEngine *engine, int32_t suit) {
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

static bool kc_assignment_target_legal(const KCEngine *engine, int32_t target_suit) {
    for (int32_t i = 0; i < engine->last_trick_count; i++) {
        if (kc_card_matches_suit(engine->last_trick[i].card, target_suit)) {
            return true;
        }
    }
    return false;
}

static int32_t kc_pending_assignment_count(const KCEngine *engine) {
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

static bool kc_handle_drunkard(KCEngine *engine, int32_t suit) {
    if (!engine->variants.nomenclature || engine->trump < 0) {
        return false;
    }
    KCCardList *bucket = &engine->job_buckets[suit];
    for (int32_t i = 0; i < bucket->count; i++) {
        KCCard card = bucket->cards[i];
        if (card.value == 11 && card.suit == engine->trump) {
            kc_list_append(&engine->exiled[engine->year], card);
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

static void kc_perform_requisition(KCEngine *engine) {
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
                kc_list_append(&engine->exiled[engine->year], revealed[i]);
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
                kc_list_append(&engine->exiled[engine->year], engine->revealed_jobs[suit]);
            }
        }
    }
    engine->year += 1;
    if (engine->year > KC_MAX_YEARS) {
        kc_finish_game(engine);
        return;
    }
    engine->trick_count = 0;
    engine->current_trick_count = 0;
    engine->last_trick_count = 0;
    engine->last_winner = KC_NO_PLAYER;
    engine->trump = KC_NO_SUIT;
    engine->requisition_event_count = 0;
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

static bool kc_action_less(KCAction lhs, KCAction rhs) {
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

static bool kc_choose_benchmark_action(const KCAction *actions, int32_t count, KCAction *selected) {
    bool has_swap = false;
    KCAction best_swap = {0};
    int32_t best_delta = 0;
    for (int32_t i = 0; i < count; i++) {
        KCAction action = actions[i];
        if (action.kind != KC_ACTION_SWAP) {
            continue;
        }
        int32_t delta = action.plot_card.value - action.hand_card.value;
        if (!has_swap ||
            delta > best_delta ||
            (delta == best_delta && kc_action_less(action, best_swap))) {
            has_swap = true;
            best_swap = action;
            best_delta = delta;
        }
    }
    if (has_swap && best_delta > 1) {
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
    for (int32_t i = 1; i < count; i++) {
        if (kc_action_less(actions[i], best)) {
            best = actions[i];
        }
    }
    *selected = best;
    return true;
}

KCGameRunResult kc_run_benchmark_game(uint64_t seed, KCVariants variants) {
    KCEngine engine;
    kc_engine_init(&engine, seed, variants);
    KCGameRunResult result = {0};
    while (engine.phase != KC_PHASE_GAME_OVER && result.actions < 1000) {
        KCAction actions[256];
        int32_t count = kc_engine_legal_actions(&engine, actions, 256);
        KCAction selected;
        if (!kc_choose_benchmark_action(actions, count, &selected)) {
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

#define KC_GRAD_FEATURES 16

static void kc_gradient_features(const KCEngine *engine, KCAction action, int32_t legal_count, double features[KC_GRAD_FEATURES]) {
    for (int32_t i = 0; i < KC_GRAD_FEATURES; i++) {
        features[i] = 0;
    }
    features[0] = 1.0;
    features[1] = (double)engine->year / 5.0;
    features[2] = (double)engine->trick_count / 4.0;
    features[3] = (double)engine->phase / 5.0;
    features[4] = (double)engine->current_player / 3.0;
    features[5] = (double)action.kind / 7.0;
    features[6] = action.suit >= 0 ? (double)action.suit / 3.0 : 0.0;
    features[7] = action.card.suit >= 0 ? (double)action.card.suit / 3.0 : 0.0;
    features[8] = kc_raw_card_value_feature(action.card.value);
    features[9] = kc_raw_card_value_feature(action.hand_card.value);
    features[10] = kc_raw_card_value_feature(action.plot_card.value);
    features[11] = (double)(action.plot_card.value - action.hand_card.value) / (double)KC_WRECKER_VALUE;
    features[12] = action.target_suit >= 0 ? (double)action.target_suit / 3.0 : 0.0;
    features[13] = (double)legal_count / 64.0;
    features[14] = action.kind == KC_ACTION_SWAP ? 1.0 : 0.0;
    features[15] = (action.kind == KC_ACTION_SUBMIT_ASSIGNMENTS || action.kind == KC_ACTION_CONTINUE_AFTER_REQUISITION) ? 1.0 : 0.0;
}

static double kc_dot(const double weights[KC_GRAD_FEATURES], const double features[KC_GRAD_FEATURES]) {
    double score = 0;
    for (int32_t i = 0; i < KC_GRAD_FEATURES; i++) {
        score += weights[i] * features[i];
    }
    return score;
}

static bool kc_choose_gradient_action(
    const KCEngine *engine,
    const KCAction *actions,
    int32_t count,
    const double weights[KC_GRAD_FEATURES],
    KCAction *selected,
    double gradient[KC_GRAD_FEATURES]
) {
    if (count <= 0) {
        return false;
    }

    double features[256][KC_GRAD_FEATURES];
    double scores[256];
    int32_t chosen = 0;
    double best_score = 0;
    for (int32_t index = 0; index < count; index++) {
        kc_gradient_features(engine, actions[index], count, features[index]);
        scores[index] = kc_dot(weights, features[index]);
        if (index == 0 || scores[index] > best_score || (scores[index] == best_score && kc_action_less(actions[index], actions[chosen]))) {
            chosen = index;
            best_score = scores[index];
        }
    }

    double max_score = scores[0];
    for (int32_t index = 1; index < count; index++) {
        if (scores[index] > max_score) {
            max_score = scores[index];
        }
    }

    double probabilities[256];
    double total = 0;
    for (int32_t index = 0; index < count; index++) {
        probabilities[index] = exp(scores[index] - max_score);
        total += probabilities[index];
    }
    if (total <= 0) {
        total = 1;
    }
    for (int32_t feature = 0; feature < KC_GRAD_FEATURES; feature++) {
        double expected = 0;
        for (int32_t index = 0; index < count; index++) {
            expected += (probabilities[index] / total) * features[index][feature];
        }
        gradient[feature] += features[chosen][feature] - expected;
    }

    *selected = actions[chosen];
    return true;
}

KCTrainingBenchmarkResult kc_run_gradient_benchmark(uint64_t seed, KCVariants variants, int32_t episodes) {
    double weights[KC_GRAD_FEATURES] = {0};
    KCTrainingBenchmarkResult result = { .episodes = episodes, .actions = 0, .checksum = 0, .weight_checksum = 0 };
    for (int32_t episode = 0; episode < episodes; episode++) {
        KCEngine engine;
        kc_engine_init(&engine, seed + (uint64_t)episode, variants);
        double gradient[KC_GRAD_FEATURES] = {0};
        int32_t episode_actions = 0;

        while (engine.phase != KC_PHASE_GAME_OVER && episode_actions < 1000) {
            KCAction actions[256];
            int32_t count = kc_engine_legal_actions(&engine, actions, 256);
            KCAction selected;
            if (!kc_choose_gradient_action(&engine, actions, count, weights, &selected, gradient)) {
                result.checksum = -999999;
                return result;
            }
            int32_t error = kc_engine_apply(&engine, selected);
            if (error != 0) {
                result.checksum = -error;
                return result;
            }
            episode_actions += 1;
        }

        int32_t player_score = kc_final_score(&engine, 0);
        int32_t best_opponent = kc_final_score(&engine, 1);
        for (int32_t player_id = 2; player_id < KC_PLAYER_COUNT; player_id++) {
            int32_t opponent_score = kc_final_score(&engine, player_id);
            if (opponent_score > best_opponent) {
                best_opponent = opponent_score;
            }
        }
        double reward = (double)(player_score - best_opponent) / 50.0;
        double step = 0.01 * reward / (double)(episode_actions > 0 ? episode_actions : 1);
        for (int32_t feature = 0; feature < KC_GRAD_FEATURES; feature++) {
            weights[feature] += step * gradient[feature];
        }

        int32_t score_sum = 0;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            score_sum += kc_final_score(&engine, player_id);
        }
        result.actions += episode_actions;
        result.checksum += engine.winner_id * 31 + score_sum;
    }
    for (int32_t feature = 0; feature < KC_GRAD_FEATURES; feature++) {
        result.weight_checksum += weights[feature] * (double)(feature + 1);
    }
    return result;
}

typedef struct {
    KCAction action;
    int32_t action_head;
    bool has_features;
    int32_t feature_count;
    int32_t feature_indices[256];
    double feature_values[256];
    double *hidden;
    double score;
} KCPolicyActionCandidate;

static double kc_uniform_from_state(uint64_t *state) {
    if (*state == 0) {
        *state = 1;
    }
    *state = *state * 6364136223846793005ULL + 1442695040888963407ULL;
    return (double)(*state >> 11) / (double)(1ULL << 53);
}

static int32_t kc_policy_parameter_count(KCPolicyModelBuffer model) {
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

static int32_t kc_policy_activation_count(KCPolicyModelBuffer model) {
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

static int32_t kc_policy_layer_count(KCPolicyModelBuffer model) {
    return kc_policy_uses_layer_stack(model) ? model.layer_count : 1;
}

static int32_t kc_policy_layer_size(KCPolicyModelBuffer model, int32_t layer) {
    return kc_policy_uses_layer_stack(model) ? model.layer_sizes[layer] : model.hidden_size;
}

static int32_t kc_policy_layer_input_size(KCPolicyModelBuffer model, int32_t layer) {
    return layer == 0 ? model.input_size : kc_policy_layer_size(model, layer - 1);
}

static double *kc_policy_layer_weights(KCPolicyModelBuffer model, int32_t layer) {
    return kc_policy_uses_layer_stack(model) ? model.layer_weights[layer] : model.w1;
}

static double *kc_policy_layer_biases(KCPolicyModelBuffer model, int32_t layer) {
    return kc_policy_uses_layer_stack(model) ? model.layer_biases[layer] : model.b1;
}

static double *kc_policy_output_weights(KCPolicyModelBuffer model) {
    return kc_policy_uses_layer_stack(model) ? model.output_weights : model.w2;
}

static int32_t kc_policy_layer_activation_offset(KCPolicyModelBuffer model, int32_t layer) {
    int32_t offset = 0;
    for (int32_t index = 0; index < layer; index++) {
        offset += kc_policy_layer_size(model, index);
    }
    return offset;
}

static int32_t kc_policy_output_offset(KCPolicyModelBuffer model) {
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

static int32_t kc_total_medals_for_player(const KCEngine *engine, int32_t player_id) {
    if (player_id < 0 || player_id >= KC_PLAYER_COUNT) {
        return 0;
    }
    return engine->players[player_id].plot_medals + engine->players[player_id].medals;
}

int32_t kc_total_medals(const KCEngine *engine, int32_t player_id) {
    return kc_total_medals_for_player(engine, player_id);
}

static bool kc_player_beats_player(const int32_t *scores, const int32_t *medals, int32_t lhs, int32_t rhs) {
    if (scores[lhs] != scores[rhs]) {
        return scores[lhs] > scores[rhs];
    }
    if (medals[lhs] != medals[rhs]) {
        return medals[lhs] > medals[rhs];
    }
    return lhs > rhs;
}

static double kc_model_score_cached(KCPolicyModelBuffer model, const KCPolicyActionCandidate *candidate, double *hidden_values) {
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

static void kc_add_cached_score_gradient(KCPolicyModelBuffer model, const KCPolicyActionCandidate *candidate, double scale, double *gradient) {
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

    double upstream[activation_count];
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

static bool kc_would_currently_win(const KCEngine *engine, KCCard card) {
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

static int32_t kc_revealed_plot_count_for_player(const KCPlayer *player, int32_t suit) {
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

static int32_t kc_hidden_plot_count_for_player(const KCPlayer *player, int32_t suit) {
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

static int32_t kc_known_score_for_player(const KCEngine *engine, int32_t player_id) {
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
                    if (hand_min == 0 || value < hand_min) hand_min = value;
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

        for (int32_t target = 0; target < KC_SUIT_COUNT; target++) {
            int32_t base = 96 + target * 12;
            int32_t own_hand_count = 0;
            int32_t own_hand_max = 0;
            int32_t own_hand_min = 0;
            int32_t all_revealed = 0;
            int32_t all_hidden = 0;
            int32_t trick_suit_count = 0;
            for (int32_t i = 0; i < player->hand.count; i++) {
                if (!kc_card_matches_suit(player->hand.cards[i], target)) continue;
                int32_t value = player->hand.cards[i].value;
                own_hand_count++;
                if (value > own_hand_max) own_hand_max = value;
                if (own_hand_min == 0 || value < own_hand_min) own_hand_min = value;
            }
            for (int32_t seat = 0; seat < KC_PLAYER_COUNT; seat++) {
                all_revealed += kc_revealed_plot_count_for_player(&engine->players[seat], target);
                all_hidden += kc_hidden_plot_count_for_player(&engine->players[seat], target);
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
            kc_add_policy_feature(candidate, base + 10, (double)all_hidden / 32.0);
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
        for (int32_t i = 0; i < player->hand.count; i++) {
            if (kc_card_matches_suit(player->hand.cards[i], target) && (min_value == 0 || player->hand.cards[i].value < min_value)) min_value = player->hand.cards[i].value;
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
    int32_t own_score = kc_final_score(engine, player_id);
    int32_t best_opponent = -1000000;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == player_id) continue;
        int32_t opponent_score = kc_final_score(engine, other);
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

static int32_t kc_policy_candidates(const KCEngine *engine, int32_t player_id, KCPolicyModelBuffer model, KCPolicyActionCandidate *candidates, int32_t max_candidates, double *hidden_cache) {
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
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_HIDDEN, (double)(plot_card.value - hand_card.value) / (double)KC_WRECKER_VALUE, model.input_size, &candidates[count]);
                    candidates[count].score = kc_model_score_cached(model, &candidates[count], candidates[count].hidden);
                    count++;
                }
                for (int32_t plot_index = 0; plot_index < player->plot_revealed.count && count < max_candidates; plot_index++) {
                    KCCard plot_card = player->plot_revealed.cards[plot_index];
                    KCAction action = { .kind = KC_ACTION_SWAP, .player_id = player_id, .suit = -1, .card = kc_no_card(), .hand_card = hand_card, .plot_card = plot_card, .plot_zone = KC_ZONE_REVEALED, .target_suit = -1 };
                    candidates[count].action = action;
                    candidates[count].has_features = true;
                    candidates[count].hidden = hidden_cache + ((size_t)count * (size_t)activation_count);
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_REVEALED, (double)(plot_card.value - hand_card.value) / (double)KC_WRECKER_VALUE, model.input_size, &candidates[count]);
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
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_HIDDEN, (double)(plot_card.value - hand_card.value) / (double)KC_WRECKER_VALUE, input_size, &candidate);
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
                    kc_policy_features(engine, player_id, 1, plot_card.suit, plot_card, hand_card, KC_ZONE_REVEALED, (double)(plot_card.value - hand_card.value) / (double)KC_WRECKER_VALUE, input_size, &candidate);
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
            if (own_hand_min == 0 || card.value < own_hand_min) {
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
        swap_delta = (double)(action.plot_card.value - action.hand_card.value) / (double)KC_WRECKER_VALUE;
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

static bool kc_sample_policy_action(KCPolicyActionCandidate *candidates, int32_t count, KCPolicyModelBuffer model, uint64_t *rng_state, double temperature, double greedy_sample_rate, double *gradient, KCAction *selected) {
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

static bool kc_sample_policy_choice(KCPolicyActionCandidate *candidates, int32_t count, uint64_t *rng_state, double temperature, double greedy_sample_rate, int32_t *chosen_out, double *log_probability_out) {
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

static double kc_policy_choice_log_probability(const KCPolicyActionCandidate *candidates, int32_t count, int32_t chosen, double temperature) {
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

static bool kc_greedy_policy_action(const KCEngine *engine, int32_t player_id, KCPolicyModelBuffer model, double *hidden_cache, KCAction *selected) {
    KCPolicyActionCandidate *candidates = malloc(256 * sizeof(KCPolicyActionCandidate));
    if (!candidates) {
        return false;
    }
    int32_t count = kc_policy_candidates(engine, player_id, model, candidates, 256, hidden_cache);
    if (count <= 0) {
        free(candidates);
        return false;
    }
    int32_t best = 0;
    for (int32_t index = 1; index < count; index++) {
        if (candidates[index].score > candidates[best].score) {
            best = index;
        }
    }
    *selected = candidates[best].action;
    free(candidates);
    return true;
}

static bool kc_heuristic_policy_action(const KCEngine *engine, KCAction *selected) {
    KCAction actions[256];
    int32_t count = kc_engine_legal_actions(engine, actions, 256);
    return kc_choose_benchmark_action(actions, count, selected);
}

bool kc_engine_heuristic_policy_action(const KCEngine *engine, KCAction *selected) {
    return kc_heuristic_policy_action(engine, selected);
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

static int32_t kc_policy_candidate_index_for_action(const KCPolicyActionCandidate *candidates, int32_t count, KCAction action) {
    for (int32_t index = 0; index < count; index++) {
        if (kc_policy_action_equal(candidates[index].action, action)) {
            return index;
        }
    }
    return -1;
}

static double kc_imitation_weight_for_head(KCPolicyGradientConfig config, int32_t action_head) {
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

static int32_t kc_apply_policy_action(KCEngine *engine, KCAction action) {
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

int32_t kc_engine_apply_policy_action(KCEngine *engine, KCAction action) {
    return kc_apply_policy_action(engine, action);
}

bool kc_engine_policy_action(const KCEngine *engine, KCPolicyModelBuffer model, KCAction *selected) {
    if (!engine) {
        return false;
    }
    if (engine->phase == KC_PHASE_PLANNING && engine->is_famine) {
        return false;
    }
    int32_t player_id = engine->phase == KC_PHASE_ASSIGNMENT ? engine->last_winner : engine->current_player;
    if (player_id < 0 ||
        player_id >= KC_PLAYER_COUNT ||
        !kc_controller_is_policy(engine->controllers.seats[player_id])) {
        return false;
    }
    int32_t activation_count = kc_policy_activation_count(model);
    if (activation_count <= 0) {
        return false;
    }
    double *hidden_cache = malloc((size_t)256 * (size_t)activation_count * sizeof(double));
    if (!hidden_cache) {
        return false;
    }
    bool ok = kc_greedy_policy_action(engine, player_id, model, hidden_cache, selected);
    free(hidden_cache);
    return ok;
}

int32_t kc_engine_step_policy_automatic(KCEngine *engine, KCPolicyModelBuffer model) {
    if (!engine) {
        return 0;
    }
    if (engine->phase == KC_PHASE_PLANNING && engine->is_famine) {
        kc_advance_from_planning(engine);
        return 1;
    }
    KCAction selected;
    bool ok = kc_engine_policy_action(engine, model, &selected);
    if (!ok) {
        return 0;
    }
    int32_t error = kc_apply_policy_action(engine, selected);
    return error == 0 ? 1 : -error;
}

static int32_t kc_run_greedy_model_game(uint64_t seed, KCVariants variants, KCPolicyModelBuffer model, int32_t *scores, int32_t *medals, int32_t *winner_id) {
    KCEngine engine;
    kc_engine_init(&engine, seed, variants);
    double *hidden_cache = malloc((size_t)256 * (size_t)kc_policy_activation_count(model) * sizeof(double));
    if (!hidden_cache) {
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
        if (!kc_greedy_policy_action(&engine, player_id, model, hidden_cache, &selected)) {
            free(hidden_cache);
            return 3;
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(hidden_cache);
            return 10 + error;
        }
    }
    free(hidden_cache);
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

static int32_t kc_run_greedy_matchup_game(
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
    if (!hidden_cache) {
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
                return 3;
            }
        } else {
            KCPolicyModelBuffer selected_model = player_id == model_seat ? model : opponent_model;
            if (!kc_greedy_policy_action(&engine, player_id, selected_model, hidden_cache, &selected)) {
                free(hidden_cache);
                return 3;
            }
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(hidden_cache);
            return 10 + error;
        }
    }
    free(hidden_cache);
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
    if (!hidden_cache) {
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
            : kc_greedy_policy_action(&engine, player_id, selected_model, hidden_cache, &selected);
        if (!ok) {
            free(hidden_cache);
            result.status = 3;
            return result;
        }
        int32_t error = kc_apply_policy_action(&engine, selected);
        if (error != 0) {
            free(hidden_cache);
            result.status = 10 + error;
            return result;
        }
        result.actions += 1;
    }
    free(hidden_cache);
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
    int32_t own_score = kc_final_score(engine, player_id);
    int32_t best_opponent = -1000000;
    for (int32_t other = 0; other < KC_PLAYER_COUNT; other++) {
        if (other == player_id) continue;
        int32_t score = kc_final_score(engine, other);
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
    KCPolicyActionCandidate *candidates = malloc(256 * sizeof(KCPolicyActionCandidate));
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
                : kc_greedy_policy_action(&engine, player_id, config.opponent_model, candidate_hidden_cache, &selected);
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
    KCPolicyActionCandidate *candidates = malloc(256 * sizeof(KCPolicyActionCandidate));
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
                bool teacher_ok = kc_greedy_policy_action(&engine, player_id, config.opponent_model, candidate_hidden_cache, &teacher_action);
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
                : kc_greedy_policy_action(&engine, player_id, config.opponent_model, candidate_hidden_cache, &selected);
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
    memset(result, 0, sizeof(*result));
    int32_t param_count = kc_policy_parameter_count(model);
    double *batch_gradient = calloc((size_t)param_count, sizeof(double));
    if (!batch_gradient) {
        return 2;
    }
    double *player_gradients[KC_PLAYER_COUNT];
    for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
        player_gradients[player_id] = calloc((size_t)param_count, sizeof(double));
        if (!player_gradients[player_id]) {
            free(batch_gradient);
            for (int32_t i = 0; i < player_id; i++) free(player_gradients[i]);
            return 2;
        }
    }
    double *candidate_hidden_cache = malloc((size_t)256 * (size_t)kc_policy_activation_count(model) * sizeof(double));
    if (!candidate_hidden_cache) {
        free(batch_gradient);
        for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) free(player_gradients[i]);
        return 2;
    }
    uint64_t rng_state = config.seed == 0 ? 1 : config.seed;
    KCVariants variants;
    kc_variants_kolkhoz(&variants);

    for (int32_t episode = 1; episode <= config.episodes; episode++) {
        KCEngine engine;
        kc_engine_init(&engine, config.seed + (uint64_t)episode, variants);
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            memset(player_gradients[player_id], 0, (size_t)param_count * sizeof(double));
        }
        int32_t player_action_counts[KC_PLAYER_COUNT] = {0};
        int32_t guard_count = 0;
        while (engine.phase != KC_PHASE_GAME_OVER && guard_count < 2000) {
            guard_count++;
            if (engine.phase == KC_PHASE_REQUISITION) {
                KCAction action = { .kind = KC_ACTION_CONTINUE_AFTER_REQUISITION, .player_id = 0, .suit = -1, .card = kc_no_card(), .hand_card = kc_no_card(), .plot_card = kc_no_card(), .plot_zone = -1, .target_suit = -1 };
                kc_engine_apply(&engine, action);
                continue;
            }
            int32_t player_id = engine.phase == KC_PHASE_ASSIGNMENT ? engine.last_winner : engine.current_player;
            KCPolicyActionCandidate candidates[256];
            int32_t count = kc_policy_candidates(&engine, player_id, model, candidates, 256, candidate_hidden_cache);
            KCAction selected;
            if (!kc_sample_policy_action(candidates, count, model, &rng_state, config.temperature, config.greedy_sample_rate, player_gradients[player_id], &selected)) {
                free(candidate_hidden_cache);
                free(batch_gradient);
                for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) free(player_gradients[i]);
                return 3;
            }
            int32_t error = kc_apply_policy_action(&engine, selected);
            if (error != 0) {
                free(candidate_hidden_cache);
                free(batch_gradient);
                for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) free(player_gradients[i]);
                return 10 + error;
            }
            player_action_counts[player_id] += 1;
        }
        if (engine.phase != KC_PHASE_GAME_OVER) {
            free(candidate_hidden_cache);
            free(batch_gradient);
            for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) free(player_gradients[i]);
            return 4;
        }
        int32_t scores[KC_PLAYER_COUNT];
        int32_t medals[KC_PLAYER_COUNT];
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            scores[player_id] = kc_final_score(&engine, player_id);
            medals[player_id] = kc_total_medals_for_player(&engine, player_id);
        }
        double raw[KC_PLAYER_COUNT];
        double mean = 0;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            raw[player_id] = kc_raw_reward_for_player(scores, medals, engine.winner_id, player_id, config);
            mean += raw[player_id];
        }
        mean /= KC_PLAYER_COUNT;
        double advantage_total = 0;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) {
            double advantage = raw[player_id] - mean;
            advantage_total += advantage;
            double scale = advantage / (double)(player_action_counts[player_id] > 0 ? player_action_counts[player_id] : 1);
            kc_add_scaled(batch_gradient, player_gradients[player_id], param_count, scale);
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
            if (engine.winner_id == player_id) top_count++;
            rank_total += kc_rank_for_player(scores, medals, player_id);
            margin_total += scores[player_id] - best_opponent;
        }
        result->episodes += 1;
        int32_t episode_actions = 0;
        for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) episode_actions += player_action_counts[i];
        result->actions += episode_actions;
        result->top_rate += (double)top_count / 4.0;
        result->average_rank += (double)rank_total / 4.0;
        result->average_margin += (double)margin_total / 4.0;
        result->average_reward += mean;
        result->average_advantage += advantage_total / 4.0;
        int32_t score_sum = 0;
        for (int32_t player_id = 0; player_id < KC_PLAYER_COUNT; player_id++) score_sum += scores[player_id];
        result->checksum += engine.winner_id * 31 + score_sum;

        if (episode % config.batch_size == 0 || episode == config.episodes) {
            double norm = 0;
            double scale = 1;
            int32_t divisor = episode % config.batch_size == 0 ? config.batch_size : episode % config.batch_size;
            kc_apply_gradient_to_model(model, batch_gradient, config, divisor, &norm, &scale);
            result->batches += 1;
            result->last_gradient_norm = norm;
            result->last_clip_scale = scale;
            memset(batch_gradient, 0, (size_t)param_count * sizeof(double));
        }
    }
    result->top_rate /= (double)result->episodes;
    result->average_rank /= (double)result->episodes;
    result->average_margin /= (double)result->episodes;
    result->average_reward /= (double)result->episodes;
    result->average_advantage /= (double)result->episodes;
    result->weight_checksum = kc_policy_weight_checksum(model, NULL);
    free(candidate_hidden_cache);
    free(batch_gradient);
    for (int32_t i = 0; i < KC_PLAYER_COUNT; i++) free(player_gradients[i]);
    return 0;
}

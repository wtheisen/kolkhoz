#ifndef KOLKHOZ_C_ENGINE_H
#define KOLKHOZ_C_ENGINE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define KC_PLAYER_COUNT 4
#define KC_SUIT_COUNT 4
#define KC_MAX_YEARS 5
#define KC_MAX_CARDS 80
#define KC_MAX_STACKS 16
#define KC_POLICY_INPUT_SIZE 200
#define KC_STATE_INPUT_SIZE 200
#define KC_MAX_POLICY_HIDDEN_LAYERS 4
#define KC_MAX_OBJECT_TOKENS 256
#define KC_OBJECT_SCALAR_COUNT 8
#define KC_ACTION_SCALAR_COUNT 32

enum {
    KC_SUIT_WHEAT = 0,
    KC_SUIT_SUNFLOWER = 1,
    KC_SUIT_POTATO = 2,
    KC_SUIT_BEET = 3,
    KC_SUIT_WRECKER = 4
};

enum {
    KC_PHASE_PLANNING = 0,
    KC_PHASE_SWAP = 1,
    KC_PHASE_TRICK = 2,
    KC_PHASE_ASSIGNMENT = 3,
    KC_PHASE_REQUISITION = 4,
    KC_PHASE_GAME_OVER = 5
};

enum {
    KC_ACTION_SET_TRUMP = 1,
    KC_ACTION_SWAP = 2,
    KC_ACTION_CONFIRM_SWAP = 3,
    KC_ACTION_PLAY_CARD = 4,
    KC_ACTION_ASSIGN = 5,
    KC_ACTION_SUBMIT_ASSIGNMENTS = 6,
    KC_ACTION_CONTINUE_AFTER_REQUISITION = 7,
    KC_ACTION_UNDO_SWAP = 8
};

enum {
    KC_CONTROLLER_EXTERNAL = 0,
    KC_CONTROLLER_HEURISTIC_AI = 1,
    KC_CONTROLLER_POLICY_AI = 2
};

enum {
    KC_OBJECT_GLOBAL = 0,
    KC_OBJECT_PLAYER = 1,
    KC_OBJECT_JOB = 2,
    KC_OBJECT_CARD = 3,
    KC_OBJECT_ASSIGNMENT = 4,
    KC_OBJECT_BELIEF = 5
};

enum {
    KC_OBJECT_ZONE_NONE = 0,
    KC_OBJECT_ZONE_HAND = 1,
    KC_OBJECT_ZONE_PLOT_REVEALED = 2,
    KC_OBJECT_ZONE_PLOT_HIDDEN = 3,
    KC_OBJECT_ZONE_STACK_REVEALED = 4,
    KC_OBJECT_ZONE_STACK_HIDDEN = 5,
    KC_OBJECT_ZONE_JOB_PILE = 6,
    KC_OBJECT_ZONE_REVEALED_JOB = 7,
    KC_OBJECT_ZONE_JOB_BUCKET = 8,
    KC_OBJECT_ZONE_CURRENT_TRICK = 9,
    KC_OBJECT_ZONE_LAST_TRICK = 10,
    KC_OBJECT_ZONE_EXILED = 11,
    KC_OBJECT_ZONE_ACCUMULATED_JOB = 12,
    KC_OBJECT_ZONE_DRUNKARD_REPLACEMENT = 13,
    KC_OBJECT_ZONE_UNKNOWN_HIDDEN = 14,
    KC_OBJECT_ZONE_PENDING_ASSIGNMENT = 15
};

typedef struct {
    int32_t suit;
    int32_t value;
} KCCard;

typedef struct {
    int32_t kind;
    int32_t player_id;
    int32_t suit;
    KCCard card;
    KCCard hand_card;
    KCCard plot_card;
    int32_t plot_zone;
    int32_t target_suit;
} KCAction;

typedef struct {
    int32_t deck_type;
    int32_t max_years;
    bool nomenclature;
    bool allow_swap;
    bool northern_style;
    bool mice_variant;
    bool orden_nachalniku;
    bool medals_count;
    bool accumulate_jobs;
    bool hero_of_soviet_union;
    bool wrecker;
} KCVariants;

typedef struct {
    int32_t seats[KC_PLAYER_COUNT];
} KCControllers;

typedef struct {
    KCCard cards[KC_MAX_CARDS];
    int32_t count;
} KCCardList;

typedef struct {
    KCCard revealed[KC_MAX_CARDS];
    int32_t revealed_count;
    KCCard hidden[KC_MAX_CARDS];
    int32_t hidden_count;
} KCPlotStack;

typedef struct {
    int32_t id;
    bool is_human;
    KCCardList hand;
    KCCardList plot_revealed;
    KCCardList plot_hidden;
    int32_t plot_medals;
    KCPlotStack stacks[KC_MAX_STACKS];
    int32_t stack_count;
    bool brigade_leader;
    bool has_won_trick_this_year;
    int32_t medals;
} KCPlayer;

typedef struct {
    int32_t player_id;
    KCCard card;
} KCTrickPlay;

typedef struct {
    int32_t player_id;
    int32_t suit;
    KCCard card;
    int32_t message_kind;
} KCRequisitionEvent;

typedef struct {
    int32_t actions;
    int32_t checksum;
} KCGameRunResult;

typedef struct {
    int32_t input_size;
    int32_t hidden_size;
    int32_t layer_count;
    int32_t layer_sizes[KC_MAX_POLICY_HIDDEN_LAYERS];
    int32_t head_count;
    double *w1;
    double *b1;
    double *layer_weights[KC_MAX_POLICY_HIDDEN_LAYERS];
    double *layer_biases[KC_MAX_POLICY_HIDDEN_LAYERS];
    double *w2;
    double *output_weights;
    double *b2;
    double *b2s;
} KCPolicyModelBuffer;

typedef struct {
    int32_t episodes;
    int32_t batch_size;
    uint64_t seed;
    double learning_rate;
    double temperature;
    double max_gradient_norm;
    double l2;
    double win_weight;
    double strict_weight;
    double rank_weight;
    double margin_weight;
    double score_delta_weight;
    double margin_delta_weight;
    double work_delta_weight;
    double claim_delta_weight;
    double own_requisition_weight;
    int32_t thread_count;
    double greedy_sample_rate;
    double advantage_baseline_beta;
    double advantage_clip;
    double value_learning_rate;
    double *value_weights;
    int32_t training_seat_count;
    int32_t training_seats[KC_PLAYER_COUNT];
    bool round_curriculum;
    int32_t round_plot_cards;
    double round_famine_rate;
    bool has_opponent_model;
    bool opponent_is_heuristic;
    bool paired_baseline;
    bool freeze_hidden;
    bool per_transition_value_advantages;
    bool phase_balanced_ppo;
    bool use_ppo;
    bool use_adam;
    double imitation_weight;
    double imitation_trump_weight;
    double imitation_swap_weight;
    double imitation_play_weight;
    double imitation_assign_weight;
    double teacher_forcing_rate;
    int32_t ppo_epochs;
    int32_t ppo_minibatch_size;
    double ppo_clip;
    double entropy_weight;
    double adam_beta1;
    double adam_beta2;
    double adam_epsilon;
    KCPolicyModelBuffer opponent_model;
} KCPolicyGradientConfig;

typedef struct {
    int32_t episodes;
    int32_t actions;
    int32_t batches;
    int32_t checksum;
    double top_rate;
    double average_rank;
    double average_margin;
    double average_reward;
    double average_advantage;
    double last_gradient_norm;
    double last_clip_scale;
    double average_ppo_kl;
    double average_ppo_abs_kl;
    double average_ppo_entropy;
    double average_ppo_clip_fraction;
    double weight_checksum;
} KCPolicyGradientResult;

typedef struct {
    int32_t status;
    int32_t actions;
    int32_t checksum;
    int32_t scores[KC_PLAYER_COUNT];
    int32_t medals[KC_PLAYER_COUNT];
    int32_t winner_id;
} KCPolicyMatchupGameResult;

typedef struct {
    KCAction action;
    int32_t action_head;
    int32_t feature_count;
    int32_t feature_indices[256];
    double feature_values[256];
} KCPolicyActionFeatures;

typedef struct {
    int32_t type;
    int32_t owner;
    int32_t zone;
    int32_t suit;
    int32_t value;
    int32_t index;
    double scalars[KC_OBJECT_SCALAR_COUNT];
} KCObjectToken;

typedef struct {
    KCAction *actions;
    int32_t *action_heads;
    int32_t *kind_ids;
    int32_t *player_ids;
    int32_t *suit_ids;
    int32_t *target_suit_ids;
    int32_t *card_suit_ids;
    int32_t *card_value_ids;
    int32_t *hand_suit_ids;
    int32_t *hand_value_ids;
    int32_t *plot_suit_ids;
    int32_t *plot_value_ids;
    int32_t *plot_zone_ids;
    float *action_scalars;
    int32_t action_scalar_count;
    float *features;
    int32_t max_actions;
    int32_t input_size;
} KCDensePolicyActionFeatures;

typedef struct {
    int32_t *type_ids;
    int32_t *owner_ids;
    int32_t *zone_ids;
    int32_t *suit_ids;
    int32_t *value_ids;
    int32_t *index_ids;
    float *scalars;
    int32_t max_tokens;
} KCDenseObjectTokens;

typedef struct {
    uint64_t rng_state;
    KCVariants variants;
    KCPlayer players[KC_PLAYER_COUNT];
    int32_t lead;
    int32_t year;
    int32_t trump;
    KCControllers controllers;
    KCCardList job_piles[KC_SUIT_COUNT];
    KCCard revealed_jobs[KC_SUIT_COUNT];
    bool has_revealed_job[KC_SUIT_COUNT];
    bool claimed_jobs[KC_SUIT_COUNT];
    int32_t work_hours[KC_SUIT_COUNT];
    KCCardList job_buckets[KC_SUIT_COUNT];
    int32_t job_bucket_tricks[KC_SUIT_COUNT][KC_MAX_CARDS];
    KCTrickPlay current_trick[KC_PLAYER_COUNT];
    int32_t current_trick_count;
    KCTrickPlay last_trick[KC_PLAYER_COUNT];
    int32_t last_trick_count;
    int32_t last_winner;
    int32_t trick_count;
    KCCardList exiled[KC_MAX_YEARS + 1];
    int32_t exiled_player_ids[KC_MAX_YEARS + 1][KC_MAX_CARDS];
    bool is_famine;
    int32_t phase;
    int32_t current_player;
    int32_t trump_selector;
    int32_t pending_assignment_targets[KC_PLAYER_COUNT];
    KCRequisitionEvent requisition_events[KC_MAX_CARDS];
    int32_t requisition_event_count;
    int32_t game_scores[KC_PLAYER_COUNT];
    int32_t winner_id;
    KCCardList accumulated_job_cards[KC_SUIT_COUNT];
    KCCardList drunkard_replacements;
    bool swap_confirmed[KC_PLAYER_COUNT];
    bool swap_count[KC_PLAYER_COUNT];
    bool has_last_swap;
    int32_t last_swap_player_id;
    int32_t last_swap_plot_zone;
    int32_t last_swap_plot_index;
    int32_t last_swap_hand_index;
    KCCard last_swap_new_plot_card;
    KCRequisitionEvent requisition_plan[KC_MAX_CARDS];
    int32_t requisition_plan_count;
    int32_t requisition_plan_index;
} KCEngine;

void kc_variants_kolkhoz(KCVariants *variants);
void kc_controllers_all_external(KCControllers *controllers);
void kc_controllers_default_single_player(KCControllers *controllers);
void kc_controllers_set(KCControllers *controllers, int32_t player_id, int32_t controller);
void kc_engine_init(KCEngine *engine, uint64_t seed, KCVariants variants);
void kc_engine_init_with_controllers(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers);
void kc_engine_init_with_controllers_stepwise(KCEngine *engine, uint64_t seed, KCVariants variants, KCControllers controllers);
void kc_engine_init_curriculum(KCEngine *engine, uint64_t seed, KCVariants variants, int32_t plot_cards_per_player, double second_year_famine_rate);
void kc_engine_init_curriculum_rounds(KCEngine *engine, uint64_t seed, KCVariants variants, int32_t plot_cards_per_player, double final_round_famine_rate, int32_t curriculum_rounds);
KCEngine *kc_engine_alloc(void);
void kc_engine_free(KCEngine *engine);
void kc_engine_clone(const KCEngine *source, KCEngine *out);
bool kc_engine_sample_determinization(const KCEngine *source, int32_t perspective_player, uint64_t sample_seed, KCEngine *out);
int32_t kc_engine_apply(KCEngine *engine, KCAction action);
int32_t kc_engine_apply_manual(KCEngine *engine, KCAction action);
int32_t kc_engine_step_automatic(KCEngine *engine);
bool kc_engine_heuristic_action(const KCEngine *engine, KCAction *selected);
int32_t kc_engine_step_policy_automatic(KCEngine *engine, KCPolicyModelBuffer model);
bool kc_engine_policy_action(const KCEngine *engine, KCPolicyModelBuffer model, KCAction *selected);
int32_t kc_engine_apply_ai_action(KCEngine *engine, KCAction action);
int32_t kc_engine_apply_ai_action_stepwise(KCEngine *engine, KCAction action);
int32_t kc_engine_apply_policy_action(KCEngine *engine, KCAction action);
int32_t kc_engine_legal_actions(const KCEngine *engine, KCAction *actions, int32_t max_actions);
int32_t kc_engine_policy_action_features(const KCEngine *engine, int32_t player_id, int32_t input_size, KCPolicyActionFeatures *features, int32_t max_features);
int32_t kc_engine_policy_action_dense_features(const KCEngine *engine, int32_t player_id, KCDensePolicyActionFeatures output);
int32_t kc_engine_state_features(const KCEngine *engine, int32_t perspective_player, float *features, int32_t feature_count);
int32_t kc_engine_object_tokens(const KCEngine *engine, int32_t perspective_player, KCObjectToken *tokens, int32_t max_tokens);
int32_t kc_engine_object_token_dense_features(const KCEngine *engine, int32_t perspective_player, KCDenseObjectTokens output);
bool kc_engine_heuristic_policy_action(const KCEngine *engine, KCAction *selected);
bool kc_engine_waiting_for_external_action(const KCEngine *engine);
int32_t kc_engine_waiting_player(const KCEngine *engine);
int32_t kc_engine_phase(const KCEngine *engine);
int32_t kc_engine_year(const KCEngine *engine);
int32_t kc_visible_score(const KCEngine *engine, int32_t player_id);
int32_t kc_final_score(const KCEngine *engine, int32_t player_id);
int32_t kc_total_medals(const KCEngine *engine, int32_t player_id);
int32_t kc_engine_current_player(const KCEngine *engine);
int32_t kc_engine_lead_player(const KCEngine *engine);
int32_t kc_engine_trump(const KCEngine *engine);
int32_t kc_engine_trick_count(const KCEngine *engine);
int32_t kc_engine_last_winner(const KCEngine *engine);
int32_t kc_engine_winner_id(const KCEngine *engine);
bool kc_engine_is_famine(const KCEngine *engine);
int32_t kc_player_hand_count(const KCEngine *engine, int32_t player_id);
KCCard kc_player_hand_card(const KCEngine *engine, int32_t player_id, int32_t index);
int32_t kc_player_plot_revealed_count(const KCEngine *engine, int32_t player_id);
KCCard kc_player_plot_revealed_card(const KCEngine *engine, int32_t player_id, int32_t index);
int32_t kc_player_plot_hidden_count(const KCEngine *engine, int32_t player_id);
KCCard kc_player_plot_hidden_card(const KCEngine *engine, int32_t player_id, int32_t index);
int32_t kc_player_plot_stack_count(const KCEngine *engine, int32_t player_id);
int32_t kc_player_plot_stack_revealed_count(const KCEngine *engine, int32_t player_id, int32_t stack_index);
KCCard kc_player_plot_stack_revealed_card(const KCEngine *engine, int32_t player_id, int32_t stack_index, int32_t card_index);
int32_t kc_player_plot_stack_hidden_count(const KCEngine *engine, int32_t player_id, int32_t stack_index);
KCCard kc_player_plot_stack_hidden_card(const KCEngine *engine, int32_t player_id, int32_t stack_index, int32_t card_index);
int32_t kc_player_medals(const KCEngine *engine, int32_t player_id);
int32_t kc_player_banked_medals(const KCEngine *engine, int32_t player_id);
bool kc_player_brigade_leader(const KCEngine *engine, int32_t player_id);
bool kc_player_won_trick_this_year(const KCEngine *engine, int32_t player_id);
bool kc_has_revealed_job(const KCEngine *engine, int32_t suit);
KCCard kc_revealed_job_card(const KCEngine *engine, int32_t suit);
bool kc_claimed_job(const KCEngine *engine, int32_t suit);
int32_t kc_work_hours(const KCEngine *engine, int32_t suit);
int32_t kc_job_bucket_count(const KCEngine *engine, int32_t suit);
KCCard kc_job_bucket_card(const KCEngine *engine, int32_t suit, int32_t index);
int32_t kc_job_bucket_trick(const KCEngine *engine, int32_t suit, int32_t index);
int32_t kc_current_trick_count(const KCEngine *engine);
int32_t kc_current_trick_player(const KCEngine *engine, int32_t index);
KCCard kc_current_trick_card(const KCEngine *engine, int32_t index);
int32_t kc_last_trick_count(const KCEngine *engine);
int32_t kc_last_trick_player(const KCEngine *engine, int32_t index);
KCCard kc_last_trick_card(const KCEngine *engine, int32_t index);
int32_t kc_pending_assignment_target(const KCEngine *engine, int32_t index);
int32_t kc_exiled_count(const KCEngine *engine, int32_t year);
KCCard kc_exiled_card(const KCEngine *engine, int32_t year, int32_t index);
int32_t kc_exiled_player(const KCEngine *engine, int32_t year, int32_t index);
int32_t kc_requisition_event_count(const KCEngine *engine);
int32_t kc_requisition_event_player(const KCEngine *engine, int32_t index);
int32_t kc_requisition_event_suit(const KCEngine *engine, int32_t index);
KCCard kc_requisition_event_card(const KCEngine *engine, int32_t index);
int32_t kc_requisition_event_message_kind(const KCEngine *engine, int32_t index);
bool kc_swap_count(const KCEngine *engine, int32_t player_id);
bool kc_swap_confirmed(const KCEngine *engine, int32_t player_id);
int32_t kc_legal_action_count(const KCEngine *engine);
int32_t kc_legal_action_kind_at(const KCEngine *engine, int32_t index);
int32_t kc_legal_action_player_at(const KCEngine *engine, int32_t index);
int32_t kc_legal_action_suit_at(const KCEngine *engine, int32_t index);
KCCard kc_legal_action_card_at(const KCEngine *engine, int32_t index);
KCCard kc_legal_action_hand_card_at(const KCEngine *engine, int32_t index);
KCCard kc_legal_action_plot_card_at(const KCEngine *engine, int32_t index);
int32_t kc_legal_action_plot_zone_at(const KCEngine *engine, int32_t index);
int32_t kc_legal_action_target_suit_at(const KCEngine *engine, int32_t index);
int32_t kc_engine_apply_set_trump(KCEngine *engine, int32_t player_id, int32_t suit);
int32_t kc_engine_apply_play_card(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value);
int32_t kc_engine_apply_swap(KCEngine *engine, int32_t player_id, int32_t hand_suit, int32_t hand_value, int32_t plot_suit, int32_t plot_value, int32_t plot_zone);
int32_t kc_engine_apply_assign(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value, int32_t target_suit);
int32_t kc_engine_apply_simple(KCEngine *engine, int32_t kind, int32_t player_id);
int32_t kc_engine_apply_set_trump_manual(KCEngine *engine, int32_t player_id, int32_t suit);
int32_t kc_engine_apply_play_card_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value);
int32_t kc_engine_apply_swap_manual(KCEngine *engine, int32_t player_id, int32_t hand_suit, int32_t hand_value, int32_t plot_suit, int32_t plot_value, int32_t plot_zone);
int32_t kc_engine_apply_assign_manual(KCEngine *engine, int32_t player_id, int32_t suit, int32_t value, int32_t target_suit);
int32_t kc_engine_apply_simple_manual(KCEngine *engine, int32_t kind, int32_t player_id);
KCGameRunResult kc_run_benchmark_game(uint64_t seed, KCVariants variants);
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
);
int32_t kc_train_policy_gradient(KCPolicyModelBuffer model, KCPolicyGradientConfig config, KCPolicyGradientResult *result);

#ifdef __cplusplus
}
#endif

#endif

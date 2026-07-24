#ifndef KOLKHOZ_C_ENGINE_INTERNAL_H
#define KOLKHOZ_C_ENGINE_INTERNAL_H

#include "KolkhozCEngine.h"

enum {
    KC_WORK_THRESHOLD = 40,
    KC_WRECKER_VALUE = 0,
    KC_POLICY_CARD_VALUE_SCALE = 14,
    KC_NO_SUIT = -1,
    KC_NO_PLAYER = -1,
    KC_ZONE_HIDDEN = 0,
    KC_ZONE_REVEALED = 1,
    KC_ERR_WRONG_PHASE = 1,
    KC_ERR_WRONG_PLAYER = 2,
    KC_ERR_INVALID_CARD = 3,
    KC_ERR_INVALID_ASSIGNMENT = 4
};

#define KC_VALUE_INPUT_SIZE 64
#define KC_MAX_POLICY_DECISIONS 256
#define KC_MAX_POLICY_ACTIVATIONS 4096

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

KCCard kc_no_card(void);
bool kc_card_equal(KCCard a, KCCard b);
bool kc_card_is_wrecker(KCCard card);
bool kc_card_valid(KCCard card);
bool kc_card_matches_suit(KCCard card, int32_t suit);
int32_t kc_lead_suit(const KCEngine *engine);
void kc_engine_begin_transition_batch(KCEngine *engine);
void kc_engine_end_transition_batch(KCEngine *engine);
bool kc_valid_player_id(int32_t player_id);
bool kc_valid_suit(int32_t suit);
bool kc_controller_is_policy(int32_t controller);
int32_t kc_work_value(const KCEngine *engine, KCCard card);
bool kc_job_contains_wrecker(const KCEngine *engine, int32_t suit);
bool kc_assignment_target_legal(const KCEngine *engine, int32_t target_suit);
bool kc_is_valid_play(const KCEngine *engine, int32_t player_id, int32_t card_index);
bool kc_action_less(KCAction lhs, KCAction rhs);
bool kc_would_currently_win(const KCEngine *engine, KCCard card);
bool kc_curriculum_should_continue(const KCEngine *engine, bool curriculum, int32_t starting_year);
bool kc_curriculum_incomplete(const KCEngine *engine, bool curriculum, int32_t starting_year);
void kc_advance_from_planning(KCEngine *engine);
int32_t kc_pending_assignment_count(const KCEngine *engine);
bool kc_choose_benchmark_action(const KCEngine *engine, const KCAction *actions, int32_t count, KCAction *selected);
bool kc_heuristic_policy_action(const KCEngine *engine, KCAction *selected);
double kc_uniform_from_state(uint64_t *state);
int32_t kc_policy_parameter_count(KCPolicyModelBuffer model);
int32_t kc_policy_activation_count(KCPolicyModelBuffer model);
int32_t kc_policy_layer_count(KCPolicyModelBuffer model);
int32_t kc_policy_layer_size(KCPolicyModelBuffer model, int32_t layer);
int32_t kc_policy_layer_input_size(KCPolicyModelBuffer model, int32_t layer);
double *kc_policy_layer_weights(KCPolicyModelBuffer model, int32_t layer);
double *kc_policy_layer_biases(KCPolicyModelBuffer model, int32_t layer);
double *kc_policy_output_weights(KCPolicyModelBuffer model);
int32_t kc_policy_layer_activation_offset(KCPolicyModelBuffer model, int32_t layer);
int32_t kc_policy_output_offset(KCPolicyModelBuffer model);
double kc_model_score_cached(KCPolicyModelBuffer model, const KCPolicyActionCandidate *candidate, double *hidden_values);
void kc_add_cached_score_gradient(KCPolicyModelBuffer model, const KCPolicyActionCandidate *candidate, double scale, double *gradient);
int32_t kc_total_medals_for_player(const KCEngine *engine, int32_t player_id);
bool kc_player_beats_player(const int32_t *scores, const int32_t *medals, int32_t lhs, int32_t rhs);
int32_t kc_revealed_plot_count_for_player(const KCPlayer *player, int32_t suit);
int32_t kc_hidden_plot_count_for_player(const KCPlayer *player, int32_t suit);
int32_t kc_known_score_for_player(const KCEngine *engine, int32_t player_id);
int32_t kc_policy_candidates(const KCEngine *engine, int32_t player_id, KCPolicyModelBuffer model, KCPolicyActionCandidate *candidates, int32_t max_candidates, double *hidden_cache);
bool kc_sample_policy_action(KCPolicyActionCandidate *candidates, int32_t count, KCPolicyModelBuffer model, uint64_t *rng_state, double temperature, double greedy_sample_rate, double *gradient, KCAction *selected);
bool kc_sample_policy_choice(KCPolicyActionCandidate *candidates, int32_t count, uint64_t *rng_state, double temperature, double greedy_sample_rate, int32_t *chosen_out, double *log_probability_out);
double kc_policy_choice_log_probability(const KCPolicyActionCandidate *candidates, int32_t count, int32_t chosen, double temperature);
bool kc_greedy_policy_action(const KCEngine *engine, int32_t player_id, KCPolicyModelBuffer model, KCPolicyActionCandidate *candidates, double *hidden_cache, KCAction *selected);
int32_t kc_policy_candidate_index_for_action(const KCPolicyActionCandidate *candidates, int32_t count, KCAction action);
double kc_imitation_weight_for_head(KCPolicyGradientConfig config, int32_t action_head);
int32_t kc_apply_policy_action(KCEngine *engine, KCAction action);
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
);

#endif

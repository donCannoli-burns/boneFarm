script "boneFarm.ash";

// boneFarm.ash
// Farm Skeleton of Crimbo Past knucklebones at The Skeleton Store.
// Requires a custom outfit, mood, and CCS named "bonefarm".

familiar BONEFARM_FAMILIAR = $familiar[Skeleton of Crimbo Past];
item BONEFARM_CROOK = $item[small peppermint-flavored sugar walking crook];
location BONEFARM_LOCATION = $location[The Skeleton Store];
string BONEFARM_OUTFIT = "bonefarm";
string BONEFARM_MOOD = "bonefarm";
string BONEFARM_CCS = "bonefarm";
int BONEFARM_DAILY_CAP = 100;
int BONEFARM_RESERVE_ADVENTURES = 2;
int BONEFARM_SKELETON_STORE_CHOICE = 1060;
int BONEFARM_SKELETON_STORE_SKIP = 5;
string BONEFARM_SKELETON_STORE_PREF = "choiceAdventure1060";
string [int] BONEFARM_MOOD_TRIGGERS;
boolean BONEFARM_MANUAL_MOOD = false;

boolean bonefarm_is_mcd_action(string action)
{
    string normalized = to_lower_case(action);
    return starts_with(normalized, "mcd ") ||
        starts_with(normalized, "mind-control ") ||
        starts_with(normalized, "mind control ");
}

boolean bonefarm_is_skill_action(string action)
{
    string normalized = to_lower_case(action);
    return starts_with(normalized, "cast ") || starts_with(normalized, "buff ");
}

boolean bonefarm_unstackable_action(string action)
{
    string normalized = to_lower_case(action);
    return contains_text(normalized, "absinthe") ||
        contains_text(normalized, "astral mushroom") ||
        contains_text(normalized, "oasis") ||
        contains_text(normalized, "turtle pheromones") ||
        contains_text(normalized, "gong");
}

boolean bonefarm_trigger_due(string trigger_type, string trigger_name, string action)
{
    if (trigger_type == "unconditional")
    {
        return true;
    }

    effect trigger_effect = to_effect(trigger_name);
    int active_turns = have_effect(trigger_effect);

    if (trigger_type == "gain_effect")
    {
        return active_turns > 0;
    }

    if (trigger_type == "lose_effect")
    {
        if (bonefarm_unstackable_action(action))
        {
            return active_turns == 0;
        }

        // KoLmafia's normal between-battle mood maintenance executes lose-effect
        // triggers when the effect has 1 turn or less remaining.
        return active_turns <= 1;
    }

    return false;
}

void bonefarm_run_manual_mood_pass(boolean skill_pass)
{
    foreach i, trigger in BONEFARM_MOOD_TRIGGERS
    {
        string [int] parts = split_string(trigger, " \\| ");
        if (count(parts) < 3)
        {
            print("WARNING: boneFarm could not parse mood trigger: " + trigger, "orange");
            continue;
        }

        string trigger_type = parts[0];
        string trigger_name = parts[1];
        string action = parts[2];

        if (bonefarm_is_mcd_action(action))
        {
            continue;
        }

        if (bonefarm_is_skill_action(action) != skill_pass)
        {
            continue;
        }

        if (!bonefarm_trigger_due(trigger_type, trigger_name, action))
        {
            continue;
        }

        boolean action_ok = false;
        string action_error = catch
        {
            action_ok = cli_execute(action);
        };

        if (action_error != "")
        {
            abort("boneFarm mood action failed: " + action + " :: " + action_error);
        }

        if (!action_ok)
        {
            abort("boneFarm mood action failed: " + action);
        }
    }
}

void bonefarm_maintain_mood()
{
    if (!BONEFARM_MANUAL_MOOD)
    {
        return;
    }

    // Match KoLmafia MoodManager ordering: skill actions first, then everything else.
    bonefarm_run_manual_mood_pass(true);
    bonefarm_run_manual_mood_pass(false);
}

void bonefarm_prepare_mood()
{
    BONEFARM_MOOD_TRIGGERS = mood_list();
    BONEFARM_MANUAL_MOOD = false;

    foreach i, trigger in BONEFARM_MOOD_TRIGGERS
    {
        string [int] parts = split_string(trigger, " \\| ");
        if (count(parts) >= 3 && bonefarm_is_mcd_action(parts[2]))
        {
            BONEFARM_MANUAL_MOOD = true;
            break;
        }
    }

    if (BONEFARM_MANUAL_MOOD)
    {
        print("boneFarm detected a legacy MCD trigger in the 'bonefarm' mood; " +
            "using script-managed mood maintenance for this run.", "orange");
        set_property("currentMood", "apathetic");
    }
}

int bonefarm_target_mcd()
{
    // Mysticality zodiac signs have Little Canadia's MCD, which supports level 11.
    // Other MCD variants top out at 10.
    return in_mysticality_sign() ? 11 : 10;
}

void bonefarm_set_mcd()
{
    int target_mcd = bonefarm_target_mcd();

    if (current_mcd() == target_mcd)
    {
        print("boneFarm MCD already set to " + target_mcd + ".", "gray");
        return;
    }

    boolean changed = change_mcd(target_mcd);

    if (!changed || current_mcd() != target_mcd)
    {
        print("boneFarm could not set MCD to " + target_mcd +
            "; MCD may be unavailable in this path/limit mode. Continuing at MCD " +
            current_mcd() + ".", "orange");
        return;
    }

    print("boneFarm set MCD to " + target_mcd + ".", "blue");
}

void bonefarm_restore_mcd(int original_mcd)
{
    if (current_mcd() == original_mcd)
    {
        return;
    }

    boolean restored = change_mcd(original_mcd);
    if (!restored || current_mcd() != original_mcd)
    {
        print("WARNING: Could not restore the original MCD level " + original_mcd + ".", "red");
    }
    else
    {
        print("boneFarm restored MCD to " + original_mcd + ".", "gray");
    }
}

string bonefarm_pending_choice_summary()
{
    int choice_id = last_choice();
    string summary = "choice #" + choice_id;
    string [int] options = available_choice_options();

    if (count(options) == 0)
    {
        return summary + " (KoLmafia could not parse any visible options)";
    }

    summary = summary + " options:";
    foreach decision, label in options
    {
        summary = summary + " [" + decision + "] " + label + ";";
    }

    return summary;
}

void bonefarm_preflight_session()
{
    if (!handling_choice())
    {
        return;
    }

    if (last_choice() == BONEFARM_SKELETON_STORE_CHOICE)
    {
        string [int] options = available_choice_options();
        if (options[BONEFARM_SKELETON_STORE_SKIP] != "")
        {
            print("boneFarm found pending Skeleton Store choice #" +
                BONEFARM_SKELETON_STORE_CHOICE + "; taking option " +
                BONEFARM_SKELETON_STORE_SKIP + " (skip adventure).", "blue");
            run_choice(BONEFARM_SKELETON_STORE_SKIP);

            if (!handling_choice())
            {
                return;
            }
        }
    }

    string summary = bonefarm_pending_choice_summary();

    print("boneFarm cannot start while KoLmafia is handling " + summary, "red");
    if (can_walk_from_choice())
    {
        print("This choice can be walked away from. Leave or resolve it, then rerun boneFarm.", "orange");
    }
    else
    {
        print("This choice must be resolved before boneFarm can change equipment or adventure.", "orange");
    }

    abort("boneFarm stopped before changing state: resolve " + summary + " and rerun.");
}

int bonefarm_bones_collected()
{
    return get_property("_knuckleboneDrops").to_int();
}

int bonefarm_rest_bones_collected()
{
    return get_property("_knuckleboneRests").to_int();
}

void bonefarm_run_tracker()
{
    string previous_wiki_setting = get_property("boneTrackEnableWiki");

    try
    {
        set_property("boneTrackEnableWiki", "false");
        boolean tracker_ok = cli_execute("try; call boneTrack.ash");
        if (!tracker_ok)
        {
            print("boneTrack.ash was not run; continuing boneFarm without it.", "gray");
        }
    }
    finally
    {
        set_property("boneTrackEnableWiki", previous_wiki_setting);
    }
}

void bonefarm_unlock_skeleton_store()
{
    if (get_property("questM23Meatsmith") == "unstarted")
    {
        visit_url("shop.php?whichshop=meatsmith&action=talk");
        run_choice(1);
    }
}

void bonefarm_preflight()
{
    if (!have_familiar(BONEFARM_FAMILIAR))
    {
        abort("boneFarm requires the Skeleton of Crimbo Past familiar.");
    }

    if (available_amount(BONEFARM_CROOK) < 1)
    {
        abort("boneFarm requires a small peppermint-flavored sugar walking crook.");
    }

    if (!have_outfit(BONEFARM_OUTFIT))
    {
        abort("boneFarm requires an equippable custom outfit named 'bonefarm'.");
    }
}

void bonefarm_restore_state(familiar original_familiar, item original_familiar_item,
    string original_mood, string original_ccs, int original_mcd,
    string original_choice_1060)
{
    set_property(BONEFARM_SKELETON_STORE_PREF, original_choice_1060);
    // Restore MCD before the user's original mood so their normal automation sees
    // the same monster-control state it had before boneFarm.
    bonefarm_restore_mcd(original_mcd);

    set_property("currentMood", original_mood);
    set_property("customCombatScript", original_ccs);

    if (have_familiar(original_familiar))
    {
        boolean familiar_restored = use_familiar(original_familiar);
        if (!familiar_restored)
        {
            print("WARNING: Could not restore your original familiar.", "red");
        }
    }

    boolean outfit_restored = cli_execute("outfit checkpoint");
    if (!outfit_restored)
    {
        print("WARNING: KoLmafia could not fully restore the equipment checkpoint.", "red");
    }

    if (my_familiar() == original_familiar &&
        familiar_equipped_equipment(original_familiar) != original_familiar_item)
    {
        boolean familiar_item_restored = equip($slot[familiar], original_familiar_item);
        if (!familiar_item_restored)
        {
            print("WARNING: Could not restore the original familiar equipment.", "red");
        }
    }
}

void bonefarm_farm()
{
    int start_bones = bonefarm_bones_collected();
    int start_adventures = my_adventures();
    int remaining_bones = BONEFARM_DAILY_CAP - start_bones;
    int adventure_budget = start_adventures - BONEFARM_RESERVE_ADVENTURES;

    if (adventure_budget < 0)
    {
        adventure_budget = 0;
    }

    print("Starting boneFarm at " + start_bones + "/" + BONEFARM_DAILY_CAP +
        " daily knucklebones (" + bonefarm_rest_bones_collected() + " from rests).", "blue");

    if (adventure_budget < remaining_bones)
    {
        print("You do not have enough spendable adventures to guarantee reaching the daily cap; " +
            "boneFarm will do what it can while preserving " + BONEFARM_RESERVE_ADVENTURES + ".", "orange");
    }

    while (bonefarm_bones_collected() < BONEFARM_DAILY_CAP &&
        my_adventures() > BONEFARM_RESERVE_ADVENTURES)
    {
        int bones_before = bonefarm_bones_collected();
        int adventures_before = my_adventures();

        bonefarm_maintain_mood();

        boolean adventure_ok = false;
        string adventure_error = catch
        {
            adventure_ok = adventure(1, BONEFARM_LOCATION);
        };

        if (adventure_error != "")
        {
            if (contains_text(adventure_error, "The dial only goes from 0 to 10."))
            {
                abort("boneFarm: your 'bonefarm' mood still contains an MCD command. Remove the mood's mcd 10/mcd 11 trigger entirely; boneFarm now owns MCD selection and restoration.");
            }

            abort("boneFarm: KoLmafia stopped before spending an adventure: " + adventure_error);
        }

        if (!adventure_ok)
        {
            print("KoLmafia stopped adventuring before the knucklebone cap was reached.", "red");
            break;
        }

        if (bonefarm_bones_collected() == bones_before && my_adventures() == adventures_before)
        {
            abort("boneFarm made no progress: no adventure was spent and no knucklebone was recorded.");
        }
    }

    int final_bones = bonefarm_bones_collected();
    int spent_adventures = start_adventures - my_adventures();

    if (final_bones >= BONEFARM_DAILY_CAP)
    {
        print("Congrats, you reached the daily knucklebone cap: " + final_bones + "/" +
            BONEFARM_DAILY_CAP + ".", "green");
    }
    else if (my_adventures() <= BONEFARM_RESERVE_ADVENTURES)
    {
        print("Stopped at " + final_bones + "/" + BONEFARM_DAILY_CAP +
            " knucklebones to preserve " + BONEFARM_RESERVE_ADVENTURES + " adventures.", "orange");
    }
    else
    {
        print("Stopped at " + final_bones + "/" + BONEFARM_DAILY_CAP + " knucklebones.", "orange");
    }

    print("boneFarm spent " + spent_adventures + " adventures this run.", "blue");
}

void main()
{
    bonefarm_run_tracker();

    if (bonefarm_bones_collected() >= BONEFARM_DAILY_CAP)
    {
        print("You already reached today's 100-knucklebone drop cap.", "green");
        return;
    }

    bonefarm_preflight_session();
    bonefarm_preflight();
    bonefarm_unlock_skeleton_store();

    familiar original_familiar = my_familiar();
    item original_familiar_item = familiar_equipped_equipment(original_familiar);
    string original_mood = get_property("currentMood");
    string original_ccs = get_property("customCombatScript");
    int original_mcd = current_mcd();
    string original_choice_1060 = get_property(BONEFARM_SKELETON_STORE_PREF);

    boolean checkpoint_ok = cli_execute("checkpoint");
    if (!checkpoint_ok)
    {
        abort("boneFarm could not create an equipment checkpoint.");
    }

    try
    {
        set_property(BONEFARM_SKELETON_STORE_PREF,
            BONEFARM_SKELETON_STORE_SKIP.to_string());

        if (!outfit(BONEFARM_OUTFIT))
        {
            abort("boneFarm could not equip the 'bonefarm' outfit.");
        }

        set_property("currentMood", BONEFARM_MOOD);
        set_property("customCombatScript", BONEFARM_CCS);
        bonefarm_prepare_mood();

        if (!use_familiar(BONEFARM_FAMILIAR))
        {
            abort("boneFarm could not switch to Skeleton of Crimbo Past.");
        }

        if (!equip($slot[familiar], BONEFARM_CROOK))
        {
            abort("boneFarm could not equip the small peppermint-flavored sugar walking crook.");
        }

        // boneFarm owns MCD while it runs. Legacy mood MCD commands are ignored by
        // the compatibility fallback in bonefarm_prepare_mood().
        bonefarm_set_mcd();

        bonefarm_farm();
    }
    finally
    {
        bonefarm_restore_state(original_familiar, original_familiar_item, original_mood, original_ccs,
            original_mcd, original_choice_1060);
        bonefarm_run_tracker();
    }
}

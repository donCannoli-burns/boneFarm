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
    string original_mood, string original_ccs, int original_mcd)
{
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

        boolean adventure_ok = false;
        string adventure_error = catch
        {
            adventure_ok = adventure(1, BONEFARM_LOCATION);
        };

        if (adventure_error != "")
        {
            if (contains_text(adventure_error, "The dial only goes from 0 to 10."))
            {
                abort("boneFarm: your 'bonefarm' mood tried to set MCD 11, but this character only has a 0-10 Mind Control Device. Change that mood action to 'mcd 10' (MCD 11 is only available with Little Canadia access).");
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

    bonefarm_preflight();
    bonefarm_unlock_skeleton_store();

    familiar original_familiar = my_familiar();
    item original_familiar_item = familiar_equipped_equipment(original_familiar);
    string original_mood = get_property("currentMood");
    string original_ccs = get_property("customCombatScript");
    int original_mcd = current_mcd();

    boolean checkpoint_ok = cli_execute("checkpoint");
    if (!checkpoint_ok)
    {
        abort("boneFarm could not create an equipment checkpoint.");
    }

    try
    {
        if (!outfit(BONEFARM_OUTFIT))
        {
            abort("boneFarm could not equip the 'bonefarm' outfit.");
        }

        set_property("currentMood", BONEFARM_MOOD);
        set_property("customCombatScript", BONEFARM_CCS);

        if (!use_familiar(BONEFARM_FAMILIAR))
        {
            abort("boneFarm could not switch to Skeleton of Crimbo Past.");
        }

        if (!equip($slot[familiar], BONEFARM_CROOK))
        {
            abort("boneFarm could not equip the small peppermint-flavored sugar walking crook.");
        }

        // boneFarm owns MCD while it runs. Keep MCD commands out of the bonefarm mood.
        bonefarm_set_mcd();

        bonefarm_farm();
    }
    finally
    {
        bonefarm_restore_state(original_familiar, original_familiar_item, original_mood, original_ccs,
            original_mcd);
        bonefarm_run_tracker();
    }
}

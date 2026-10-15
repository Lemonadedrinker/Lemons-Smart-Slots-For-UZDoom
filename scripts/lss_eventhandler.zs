class LSS_EventHandler : EventHandler
{
    ui bool isViewingMenu;
    ui Array<LSS_Weapon> currentWeapons; // Stored how the player orders it
    ui String bufferedWeaponString; // The weapon currently being switched to
    ui Weapon lastUsedWeapon; // Used to swap to the previous weapon
    ui Vector2 MousePosition;

    ui bool mouseClicked;
    ui bool mouseReleased;
    ui Vector2 slotSelected;
    ui bool hasSlotSelected;
    ui String selectedWeaponString;

    ui Array<Weapon> weaponList; // List of Weapons to detect if a new one is picked up
    ui Vector2 highlightedSlot; // Slot to highlight when picking up a new gun
    ui int slotTimers[10];
    ui bool hasActiveTimer; // True if there is at least one timer active
    ui PlayerInfo playerViewing; // Usually yourself
    ui String netSlots[10]; // To save whenever needed

    ui bool keyDown;
    private bool uninstallingMod;

    override void WorldLoaded(WorldEvent event)
    {
        SendInterfaceEvent(ConsolePlayer, "LSS_ResetSlotTimers");

        // Check if Icon Addon is installed
        // If so, delete the main event handler
        String className = "LSS_IconAddon";
        Class<EventHandler> cls = className;

        // If icon addon installed, AND main event handler, then delete main
        if (cls && GetClassName() == "LSS_EventHandler")
        {
            uninstallingMod = true;
        }
    }

    override void WorldThingDied(WorldEvent event)
    {
        if (event.Thing == Players[ConsolePlayer].mo)
        {
            SendInterfaceEvent(ConsolePlayer, "LSS_ForceNotEditing");
            SendInterfaceEvent(ConsolePlayer, "LSS_ResetSlotTimers");
        }
    }

    /**
    *   Forces the UI to close and stop editing
    */
    override void WorldUnloaded(WorldEvent event)
    {   
        SendInterfaceEvent(ConsolePlayer, "LSS_ForceNotEditing");
    }

    // Play to UI
    override void InterfaceProcess(ConsoleEvent event)
    {
        // Reset slot timers
        if (event.Name == "LSS_ResetSlotTimers")
        {
            //Console.printf("Resetting slots");
            for (int i = 0; i < 10; i++)
            {
                slotTimers[i] = 0;
            }

            hasActiveTimer = false;

            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";
        }
        else if (event.Name == "LSS_ForceNotEditing")
        {
            isViewingMenu = false;

            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";

            SendNetworkEvent("LSS_NotEditing");
        }
        // Forces the player being spied on to update their slots
        else if (event.Name == "LSS_UpdateNetSlots")
        {
            // Save CVars
            CVar cvar;
            int currentSlot;
            for (int i = 0; i < 10; i++)
            {
                //Console.printf(netSlots[i]);
                currentSlot = (i == 9) ? 0 : i + 1;

                // owner.player is used to transer user CVars across the network
                // players[ConsolePlayer] DOES NOT WORK!!
                cvar = CVar.GetCVar("LSS_NetSlot"..currentSlot, players[ConsolePlayer]);

                cvar.SetString(netSlots[i]);
            }
        }
    }

    /**
    * Processes keybinds
    */
    override void ConsoleProcess(ConsoleEvent event)
    {
        if(players[Consoleplayer].mo == null) return;

        // Player switches to the next weapon
        if (event.Name == "LSS_NextWeapon")
        {
            //Console.printf("Trying to switch to the next weapon!");
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerRelativeWeaponChange(true);
        }

        // Player switches to the previous weapon
        else if (event.Name == "LSS_PrevWeapon")
        {
            //Console.printf("Trying to switch to the previous weapon!");
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerRelativeWeaponChange(false);
        }

        // Player switches to a specific slot
        else if (event.Name.Left(10) == "LSS_Switch")
        {
            // Trim the digit, convert that to an int
            String digitString = event.Name;
            digitString.Remove(0, 10);
            int slot = digitString.ToInt(10);
            //Console.printf(" Slot: %i", slot);

            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerSlotNumberSelected(slot);

            // If spying, then reset the weapons to show the spying player
            if (GetSpyTarget() != players[ConsolePlayer]) UpdateCurrentWeaponsArray(true);
        }

        // Player switches to the previous weapon
        else if (event.Name == "LSS_LastWeapon")
        {
            if (lastUsedWeapon == null)
            {
                //Console.printf("No last used weapon!");
                return;
            }

            //Console.printf("Last used weapon: %s", lastUsedWeapon.GetClassName());
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerLastWeaponChange();
        }
        
        // Player tries to edit
        else if (event.Name == "LSS_Edit" && GetSpyTarget().health != 0)
        {
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();
            isViewingMenu = !isViewingMenu;
            // Check if viewing another player
            if (GetSpyTarget() != players[ConsolePlayer])
            {
                slotSelected = (-1, -1);
                hasSlotSelected = false;
                selectedWeaponString = "";
            }
            // Allow the play scope to know that the player is editing
            else if (isViewingMenu)
            {
                slotSelected = (-1, -1);
                hasSlotSelected = false;
                selectedWeaponString = "";

                for (int i = 0; i < 10; i++)
                {
                    slotTimers[i] = 0;
                }

                SendNetworkEvent("LSS_Editing");
            }
            else
            {
                SendNetworkEvent("LSS_NotEditing");
            }
            
            UpdateCurrentWeaponsArray(true);

            // Debugging
            //int randomWeaponIndex = crandom(0, currentWeapons.Size() - 1);
            //String randomWeaponName = currentWeapons[randomWeaponIndex].GetClassName();

            //SendNetworkEvent("LSS_WeaponSwitchTo" .. randomWeaponName);
        }

        // Reset Slot Settings
        else if (event.Name == "LSS_ResetSlotCustomizationSettings")
        {
            CVar.GetCvar("LSS_PreviewOnWeaponPickup", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_PreviewOnWeaponDrop", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_PreviewOnWeaponSwap", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_PreviewOnWeaponSwapSlotEmpty", players[ConsolePlayer]).ResetToDefault();

            CVar.GetCvar("LSS_AlphaValue", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_CursorOffset", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_UIVolume", players[ConsolePlayer]).ResetToDefault();

            CVar.GetCvar("LSS_PreviewAlphaValue", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_PreviewTimer", players[ConsolePlayer]).ResetToDefault();
            CVar.GetCvar("LSS_PreviewTimerFade", players[ConsolePlayer]).ResetToDefault();
        }
        // Set Color Preset
        else if (event.Name == "LSS_SetPreset")
        {
            SetColorPreset();
        }

        // Reset slots
        else if (event.Name == "LSS_ResetSlots")
        {
            CVar slotCVar;
            for (int i = 0; i < 10; i++)
            {
                slotCVar = CVar.GetCvar("LSS_Slot"..i, players[ConsolePlayer]);
                slotCvar.ResetToDefault();
            }
        }
    }

    override bool UiProcess(UiEvent event)
    {
        //Console.printf("%s", event.KeyString);

        // Hardcoded 27 is ASCII for the esc key
        if (event.KeyChar == 27)
        {
            SendInterfaceEvent(ConsolePlayer, "LSS_ForceNotEditing");
        }

        // Getting mouse inputs
        if (event.MouseX != 0 && event.MouseY != 0)
        {
            MousePosition = (event.MouseX, event.MouseY);
        }

        // Try to switch weapons
        int keyChar = event.KeyChar;
        //Console.printf("%i", keyChar);
        if (keyChar > 47 && keyChar < 58 && !keyDown)
        {
            keyDown = true;
            //Console.printf("key down %b", keyDown);

            int slot = keyChar - 48;
            int weaponSlot = (slot != 0) ? slot : 0;
            //Console.printf(" slot: %i, weaponSlot: %i", slot, weaponSlot);

            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerSlotNumberSelected(weaponSlot);

            // If spying, then reset the weapons to show the spying player
            if (GetSpyTarget() != players[ConsolePlayer]) UpdateCurrentWeaponsArray(true);
        }

        // Key released
        if (event.Type == UiEvent.Type_KeyUp && UiEvent.Type_Char)
        {
            keyDown = false;
        }

        // Mouse clicked
        if (event.Type == event.Type_LButtonDown && mouseClicked == false)
        {
            //Console.printf("Mouse clicked!");
            mouseClicked = true;
        }

        // Mouse released
        if (event.Type == event.Type_LButtonUp)
        {
            //Console.printf("Mouse released!");
            mouseReleased = true;
        }

        return true;
    }

    override void NetworkProcess(ConsoleEvent event)
    {
        //self.IsUiProcessor = !self.IsUiProcessor;
        //self.RequireMouse = !self.RequireMouse; 
            
        if(players[event.Player].mo == null) return;
        Let player = players[event.Player];

        if (event.Name.Left(18) == "LSS_WeaponSwitchTo")
        {
            String weaponName = event.Name;
            weaponName.Remove(0, 18);

            //Console.printf("%s", weaponName);
            player.mo.A_SelectWeapon(weaponName);
        }

        // *Need* to only enable the UI for the player that started editing
        // Should be safe for multiplayer
        else if (event.Name == "LSS_Editing" && player == players[ConsolePlayer])
        {
            self.IsUiProcessor = true;
            self.RequireMouse = true;
        }
        else if (event.Name == "LSS_NotEditing" && player == players[ConsolePlayer])
        {
            self.IsUiProcessor = false;
            self.RequireMouse = false;
        }

        // Update some player's net slots
        else if (event.Name.Left(17) == "LSS_UpdateNetSlot")
        {
            int currentSlot = event.Args[0];
            int playerToUpdate = event.Args[1];
            String cvarData = event.Name.Mid(17);
            //Console.printf("From %i: update %i!", event.Player, playerToUpdate);
            //Console.printf("cvarData: %s", cvarData);

            // event.Player is the person spying and requesting the inventory update
            // playerToUpdate is the one being spyed on and must update their inventory
            //SendInterfaceEvent(ConsolePlayer, "LSS_UpdateNetSlots", playerToUpdate);
            // Save CVars
            CVar cvar;

            currentSlot = (currentSlot == 9) ? 0 : currentSlot + 1;

            cvar = CVar.GetCVar("LSS_NetSlot"..currentSlot, players[playerToUpdate]);

            cvar.SetString(cvarData);
            Console.printf(cvarData);
            //Console.printf("CVar data: %s", CVar.GetCVar("LSS_NetSlot"..currentSlot, players[playerToUpdate]).GetString());
        }
        else if (event.Name.Left(7) == "LSS_???")
        {
            Console.printf("Yes it did.");
            CVar.GetCVar("LSS_NetSlot5", players[event.Player]).SetString("Did this work?");
        }

        // Uninstall the mod by deleting the event handler, only if it is the arbitrator
        else if (event.Name == "LSS_Uninstall")
        {
            //Console.printf("Trying to uninstall mod");
            //Console.printf("Player number: %i", event.Player);
            if (net_arbitrator == event.Player)
            {
                Console.printf("Uninstalling mod. Have a good day!");
                uninstallingMod = true;
            }
            else
            {
                Console.printf("Not uninstalling mod. You must be the arbitrator!");
            }
        }
    }

    override void UiTick()
    {
        if (!LSS_PreviewOnWeaponPickup && !LSS_PreviewOnWeaponDrop) return;

        bool switchedView = false;

        // Set timers to 0 if switching views
        if (playerViewing == null)
        {
            playerViewing = GetSpyTarget();
        }
        else if (playerViewing != GetSpyTarget())
        {
            //Console.printf("Switched target!");
            switchedView = true;
            
            // Kick the player out of the menu if they switch to themselves
            if (isViewingMenu && GetSpyTarget() == players[ConsolePlayer])
            {
                SendInterfaceEvent(ConsolePlayer, "LSS_ForceNotEditing");
            }

            SendInterfaceEvent(ConsolePlayer, "LSS_ResetSlotTimers");
            playerViewing = GetSpyTarget();
        }
        
        if (GetSpyTarget() != players[ConsolePlayer])
        {
            UpdateCurrentWeaponsArray(true);
            SaveCurrentWeaponsToDisk();
        }

        // Decrement the timers if one is active
        if (hasActiveTimer)
        {
            bool timerActive = false;

            for (int i = 0; i < 10; i++)
            {
                if (slotTimers[i] > 0)
                {
                    slotTimers[i]--;
                    //Console.printf("Decrementing slot: %i", i);
                    timerActive = true;
                }
            }

            hasActiveTimer = timerActive;
        }

        // GZDoom's inventory can be parsed through as a linked list, where
        // Inv is the next item in the list.
        Array<Weapon> tempWeaponList;
        Let player = GetSpyTarget();
        for (let item = player.mo.Inv; item != null; item = item.Inv)
        {
            // Cast item as a weapon
            let playerWeapon = Weapon(item);

            // If the cast fails, keep going
            if (!playerWeapon) continue;

            tempWeaponList.Push(playerWeapon);
        }

        // Do not show previews whenever the view switches
        if (!switchedView)
        {
            // If the same size, do nothing for performance
            if (weaponList.Size() == tempWeaponList.Size()) return;
            // Picked up a new weapon
            else if (weaponList.Size() < tempWeaponList.Size() && LSS_PreviewOnWeaponPickup) PlayerPickedUpNewWeapon(tempWeaponList);
            // Dropped a weapon
            else if (LSS_PreviewOnWeaponDrop) PlayerDroppedWeapon(tempWeaponList);
        }

        // Set up weaponList for the next tick.
        weaponList = tempWeaponList;
    }

    override void WorldTick()
    {
        // Delete the event handler if the mod is being uninstalled
        if (uninstallingMod)
        {
            if (!bDESTROYED)
            {
                Destroy();
            }
            return;
        }
    }

    /***
    * Iterates through the player's inventory, looking for weapons
    */
    ui void UpdateCurrentWeaponsArray(bool isCosmetic = false)
    {
        PlayerInfo player = players[ConsolePlayer];
        if (isCosmetic) player = GetSpyTarget();

        Array<LSS_Weapon> tempWeaponArray;
        int defaultSlot = -1;
        int priority;
        // GZDoom's inventory can be parsed through as a linked list, where
        // Inv is the next item in the list.
        for (let item = player.mo.Inv; item != null; item = item.Inv)
        {
            // Cast item as a weapon
            let playerWeapon = Weapon(item);

            // If the cast fails, keep going
            if (!playerWeapon) continue;

            defaultSlot = playerWeapon.SlotNumber;

            String weaponClassName = playerWeapon.GetClassName();

            // Vanilla Doom weapons need to be hardcoded because ZDoom does not
            // automatically assign slots to them (I think)
            if (weaponClassName == "Fist" || weaponClassName == "Chainsaw") defaultSlot = 1;
            else if (weaponClassName == "Pistol") defaultSlot = 2;
            else if (weaponClassName == "Shotgun" || weaponClassName == "SuperShotgun") defaultSlot = 3;
            else if (weaponClassName == "Chaingun") defaultSlot = 4;
            else if (weaponClassName == "RocketLauncher") defaultSlot = 5;
            else if (weaponClassName == "PlasmaRifle") defaultSlot = 6;
            else if (weaponClassName == "BFG9000") defaultSlot = 7;
            //else if (weaponClassName == "ID24Incinerator") defaultSlot = 8;
            //else if (weaponClassName == "ID24CalamityBlade") defaultSlot = 9;

            //Console.printf(" Weapon "..playerWeapon.GetClassName().." with defaultSlot: %i", defaultSlot);

            if (defaultSlot == -1) continue;
            
            // Weapon found!!
            let newWeapon = new('LSS_Weapon');
            newWeapon.weapon = playerWeapon;
            newWeapon.slot = defaultSlot;

            tempWeaponArray.Push(newWeapon);
            //Console.printf(" HAVE: " .. newWeapon.weapon.GetClassName() .. " in slot #" .. defaultSlot .. " and priority: " .. priority);
        }

        // Now we parse through the CVars to precompute the slots and priorities
        currentWeapons.Clear();
        int row[10];
        LSS_Weapon tempWeapon;

        // Correct version, ONLY for yourself
        if (GetSpyTarget() == players[ConsolePlayer] || !isCosmetic)
        {
            for (int slot = 0; slot < 10; slot++)
            {
                int currentSlot = (slot == 9) ? 0 : slot + 1;

                // This is the list of weapons for the slot
                String savedWeaponString = CVar.GetCvar("LSS_Slot"..currentSlot, players[ConsolePlayer]).GetString();
                //Console.printf(savedWeaponString);

                // Here the list is split by comma into the weaponList
                Array<String> savedWeaponList;
                savedWeaponString.Split(savedWeaponList, ",");

                // Check each saved weapon in the comma separated list
                for (int savedWeapon = 0; savedWeapon < savedWeaponList.Size(); savedWeapon++)
                {
                    //Console.printf("Weapon in CVar: "..savedWeaponList[savedWeapon]);
                    // Check if the saved weapon is currently held
                    // We go backwards to more easily remove weapons from the list
                    for (int currentWeapon = tempWeaponArray.Size() - 1; currentWeapon >= 0; currentWeapon--)
                    {
                        if (savedWeaponList[savedWeapon] == tempWeaponArray[currentWeapon].weapon.GetClassName())
                        {
                            tempWeapon = tempWeaponArray[currentWeapon];
                            tempWeapon.slot = slot;
                            tempWeapon.row = row[slot];
                            currentWeapons.push(tempWeapon);

                            //Console.printf(" Temp weapon: "..tempWeapon.weapon.GetClassName());

                            tempWeaponArray.Delete(currentWeapon);
                            //currentWeapon--;
                            //Console.printf(" tempWeaponArray size: "..tempWeaponArray.Size());
                            row[slot]++;
                        }
                    }
                }
            }

            // These weapons did not get popped, meaning they were not already saved in the CVar
            // Assign their default slots, priority might be unpredictable
            for (int i = 0; i < tempWeaponArray.Size(); i++)
            {
                tempWeapon = tempWeaponArray[i];
                
                int storedSlot = (tempWeapon.slot != 0) ? tempWeapon.slot - 1 : 9;

                // In case of slots out of range
                if (storedSlot > 9) storedSlot = 9;
                else if (storedSlot < 0) storedSlot = 0;

                tempWeapon.slot = storedSlot;

                tempWeapon.row = row[tempWeapon.slot];
                row[tempWeapon.slot]++;

                //Console.printf(" Temp weapon2: "..tempWeapon.weapon.GetClassName());

                //Console.printf(tempWeapon.weapon.GetClassName().." stored in slot index %i", tempWeapon.slot);

                // Finally add to the array
                currentWeapons.Push(tempWeapon);
            }
        }

        // Potentially wrong version, ONLY when spying
        else
        {
            //Console.printf("Got here");
            //Console.printf("Weapon count: %i", tempWeaponArray.Size());
            int weaponCount[10]; // Cannot exceed 8 because (19 characters, and comma) * 8 < 255 character limit
            int currentSlot;
            String weaponName;

            for (int slot = 0; slot < 10; slot++)
            {
                currentSlot = (slot == 9) ? 0 : slot + 1;

                // We can cheat here because we already know the order
                
                // This is the list of weapons for the slot
                String savedWeaponString = CVar.GetCvar("LSS_NetSlot"..currentSlot, GetSpyTarget()).GetString();
                //Console.printf(savedWeaponString);

                // Here the list is split by comma into the weaponList
                Array<String> savedWeaponList;
                savedWeaponString.Split(savedWeaponList, ",");

                // Check each saved weapon in the comma separated list
                for (int savedWeapon = 0; savedWeapon < savedWeaponList.Size(); savedWeapon++)
                {
                    //Console.printf("Weapon in CVar: "..savedWeaponList[savedWeapon]);
                    // Check if the saved weapon is currently held
                    // We go backwards to more easily remove weapons from the list
                    for (int currentWeapon = tempWeaponArray.Size() - 1; currentWeapon >= 0; currentWeapon--)
                    {
                        weaponName = tempWeaponArray[currentWeapon].weapon.GetClassName();

                        // If the first 19 characters match AND less than 8 weapons
                        if (savedWeaponList[savedWeapon] == weaponName.Left(19) &&
                            row[slot] < 8)
                        {
                            tempWeapon = tempWeaponArray[currentWeapon];
                            tempWeapon.slot = slot;
                            tempWeapon.row = row[slot];
                            currentWeapons.push(tempWeapon);

                            //Console.printf(" Temp weapon: "..tempWeapon.weapon.GetClassName());

                            tempWeaponArray.Delete(currentWeapon);
                            //currentWeapon--;
                            //Console.printf(" tempWeaponArray size: "..tempWeaponArray.Size());
                            row[slot]++;
                        }
                    }
                }
            }
        }
    }

    /***
    *   Checks if the weapons in currentWeapons are in the CVars
    *   If so, do nothing
    *   If not, then save it to the disk
    */
    ui void SaveCurrentWeaponsToDisk()
    {
        int playerIndex = ConsolePlayer;

        for (int i = 0; i < players.Size(); i++)
        {
            if (players[i] == GetSpyTarget())
            {
                playerIndex = i;
            }
        }
        // Do nothing if it's yourself
        // Send to everyone else
        if (playerIndex != ConsolePlayer)
        {
            // Save just the current weapons to the LSS Net Slot CVars so other players can see them
            // Instantiate the Strings to save
            //netSlots.Clear();
            int weaponCount[10]; // Cannot exceed 8 because (19 characters, and comma) * 10 < 255 character limit
            String weaponName;
            for (int i = 0; i < 10; i++)
            {
                netSlots[i] = ",";
            }

            // Parse each weapon and add it to the slot
            for (int i = 0; i < currentWeapons.Size(); i++)
            {
                if (weaponCount[currentWeapons[i].slot] < 8)
                {
                    weaponCount[currentWeapons[i].slot]++;
                    weaponName = currentWeapons[i].weapon.GetClassName();
                    netSlots[currentWeapons[i].slot] = ""..netSlots[currentWeapons[i].slot]..weaponName.Left(19)..",";
                }
            }

            // Send to everyone
            //SendInterfaceEvent(ConsolePlayer, "LSS_UpdateNetSlotsNum");


            for (int i = 0; i < 10; i++)
            {
                SendNetworkEvent("LSS_UpdateNetSlot"..netSlots[i], i, playerIndex);
            }
            //Console.printf("LSS_UpdateNetSlotsNum"..playerIndex);

            /*
            // Save CVars
            CVar cvar;
            for (int i = 0; i < 10; i++)
            {
                //Console.printf(netSlots[i]);
                currentSlot = (i == 9) ? 0 : i + 1;

                // owner.player is used to transer user CVars across the network
                // players[ConsolePlayer] DOES NOT WORK!!
                cvar = CVar.GetCVar("LSS_NetSlot"..currentSlot, players[ConsolePlayer]);

                cvar.SetString(netSlots[i]);
            }
            */
        }
        else
        {

            int currentSlot;
            //Console.printf(" currentWeapons.Size(): "..currentWeapons.Size());
            // Check for each weapon
            for (let i = 0; i < currentWeapons.Size(); i++)
            {
                //Console.printf(" currentWeapon: "..currentWeapons[i].weapon.GetClassName());
                // First we check if the weapons are saved
                bool isSaved = false;
                for (int slot = 0; slot < 10; slot++)
                {
                    // The slots are saved as follows:
                    // LSS_Slot2=Pistol,Shotgun,Chaingun,
                    // LSS_Slot3=BFG9000,

                    // This is the list of weapons for the slot
                    currentSlot = (slot == 9) ? 0 : slot + 1;
                    String weaponString = CVar.GetCvar("LSS_Slot"..currentSlot, players[ConsolePlayer]).GetString();
                    //Console.printf(weaponString);

                    // Here the list is split by comma into the weaponCVars
                    Array<String> weaponCVars;
                    weaponString.Split(weaponCVars, ",");

                    // Check if the weapon is in the list
                    if (weaponCVars.Find(currentWeapons[i].weapon.GetClassName()) != weaponCVars.Size())
                    {
                        //Console.printf("Weapon "..currentWeapons[i].weapon.GetClassName().." found!!");
                        isSaved = true;
                    }
                }

                // If not saved, then we save them
                if (!isSaved)
                {
                    // Read the existing cvar
                    currentSlot = (currentWeapons[i].slot == 9) ? 0 : currentWeapons[i].slot + 1;
                    CVar toSave = CVar.GetCvar("LSS_Slot"..currentSlot, players[ConsolePlayer]);

                    // Override it, appending the new weapon to the end
                    toSave.SetString(""..toSave.GetString()..currentWeapons[i].weapon.GetClassName()..",");
                }
            }
        }
    }

    /***
    *   Translates a relative weapon switch into an absolute weapon to switch to
    *   The weapon is sent over the network to every client
    */
    ui void PlayerRelativeWeaponChange(bool isNextWeapon)
    {
        //Console.printf(players[Consoleplayer].ReadyWeapon.GetClassName());

        if (players[ConsolePlayer].health == 0) return;
        
        // Checks to see if the currently held item is a weapon
        bool isWeapon = false;
        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            if (currentWeapons[i].weapon == players[Consoleplayer].ReadyWeapon)
            {
                isWeapon = true;
                break;
            }
        }

        // Check if no weapon held, then set it to an empty string
        if (players[Consoleplayer].ReadyWeapon == null)
        {
            bufferedWeaponString = "";
        }

        // The player's weapon being switched to
        // If empty, fill with the held weapon
        if (players[Consoleplayer].ReadyWeapon != null && bufferedWeaponString == "")
        {
            bufferedWeaponString = players[Consoleplayer].ReadyWeapon.GetClassName();
        }
        // Check if buffered weapon is no longer in the inventory, then set to heldweapon
        else if (players[Consoleplayer].ReadyWeapon != null)
        {
            bool inInventory = false;
            // Iterate through all weapons
            for (int i = 0; i < currentWeapons.Size(); i++)
            {
                if (currentWeapons[i].weapon.GetClassName() == bufferedWeaponString)
                {
                    inInventory = true;
                    break;
                }
            }

            if (!inInventory) bufferedWeaponString = players[Consoleplayer].ReadyWeapon.GetClassName();
        }

        // If not a weapon, then switch back to the last held weapon and end the function
        if (!isWeapon)
        {
            //Console.printf("Item to weapon swap!");
    
            // Finally, switch weapons
            //Console.Printf(currentWeapons[currentWeaponIndex].weapon.GetClassName());
            SendNetworkEvent("LSS_WeaponSwitchTo"..bufferedWeaponString);

            // Find the weapon's index
            int oldWeaponIndex;
            for (int i = 0; i < currentWeapons.Size(); i++)
            {
                if (currentWeapons[i].weapon.GetClassName() == bufferedWeaponString)
                {
                    oldWeaponIndex = i;
                    break;
                }
            }

            // Display the name of the weapon on the bottom of the screen
            currentWeapons[oldWeaponIndex].weapon.DisplayNameTag();
            return;
        }

        // Check if only one or zero weapons
        // If so, then do nothing
        //if (currentWeapons.Size() < 2) return;

        // Current weapons is already sorted
        // We need to find the index of the currently held weapon
        int currentWeaponIndex = -1;
        for (int weapon = 0; weapon < currentWeapons.Size(); weapon++)
        {
            //Console.printf(" Weapon: "..currentWeapons[weapon].weapon.GetClassName());
            if (currentWeapons[weapon].weapon.GetClassName() == bufferedWeaponString)
            {
                currentWeaponIndex = weapon;
                break;
            }
        }
        //Console.printf("currentWeaponIndex: %i", currentWeaponIndex);

        // Should never happen?
        if (currentWeaponIndex == -1) return;

        // Next weapon
        int weaponToSwitchToIndex;
        if (isNextWeapon)
        {
            // Wrap to the start if too large
            if (currentWeaponIndex == currentWeapons.Size() - 1)
            {
                weaponToSwitchToIndex = 0;
            }
            // Otherwise, increment by 1
            else
            {
                weaponToSwitchToIndex = currentWeaponIndex + 1;
            }
        }
        // Previous weapon
        else
        {
            // Wrap to the end if too small
            if (currentWeaponIndex == 0)
            {
                //Console.printf("Got here, index is 0.");
                weaponToSwitchToIndex = currentWeapons.Size() - 1;
            }
            // Otherwise, decrement by 1
            else
            {
                weaponToSwitchToIndex = currentWeaponIndex - 1;
            }
        }

        //Console.printf("weaponToSwitchToIndex: %i", weaponToSwitchToIndex);

        // Finally, switch weapons
        //Console.Printf(currentWeapons[currentWeaponIndex].weapon.GetClassName());
        bufferedWeaponString = currentWeapons[weaponToSwitchToIndex].weapon.GetClassName();
        // Only do stuff if it's a different weapon
        if (players[ConsolePlayer].ReadyWeapon != null &&
            players[ConsolePlayer].ReadyWeapon.GetClassName() != bufferedWeaponString)
        {
            // Set the last used weapon
            lastUsedWeapon = players[ConsolePlayer].ReadyWeapon;

            SendNetworkEvent("LSS_WeaponSwitchTo"..currentWeapons[weaponToSwitchToIndex].weapon.GetClassName());

            // Display the name of the weapon on the bottom of the screen
            currentWeapons[weaponToSwitchToIndex].weapon.DisplayNameTag();
        }

        // Enable the preview
        if (LSS_PreviewOnWeaponSwap)
        {
            int slotIndex = (currentWeapons[weaponToSwitchToIndex].slot > 0) ? currentWeapons[weaponToSwitchToIndex].slot - 1 : 9;
            slotIndex = currentWeapons[weaponToSwitchToIndex].slot;

            slotTimers[slotIndex] = (LSS_PreviewTimer + LSS_PreviewTimerFade) * 35;

            // Set the highlighted slot
            highlightedSlot = (slotIndex, currentWeapons[weaponToSwitchToIndex].row);
        }
    }

    /***
    *   Translates a slot number into a weapon to switch to
    *   The weapon is sent over the network to every client
    */
    ui void PlayerSlotNumberSelected(int slot)
    {
        //Console.printf(players[Consoleplayer].ReadyWeapon.GetClassName());

        if (players[ConsolePlayer].health == 0) return;

        // Check if no weapon held, then set it to an empty string
        if (players[Consoleplayer].ReadyWeapon == null)
        {
            bufferedWeaponString = "";
        }
        // Reset the weapon if the Buffered Weapon String does not match the ReadyWeapon,
        // ONLY if PendingWeapon is WP_NOCHANGE
        else if (
                bufferedWeaponString != players[Consoleplayer].ReadyWeapon.GetClassName() &&
                players[Consoleplayer].PendingWeapon == WP_NOCHANGE
            )
        {
            bufferedWeaponString = players[Consoleplayer].ReadyWeapon.GetClassName();
        }

        // The player's weapon being switched to
        // If empty, then fill
        if (bufferedWeaponString == "" && players[Consoleplayer].ReadyWeapon != null)
        {
            bufferedWeaponString = players[Consoleplayer].ReadyWeapon.GetClassName();
        }

        // This is the list of weapons for the slot
        String weaponString = CVar.GetCvar("LSS_Slot"..slot, players[ConsolePlayer]).GetString();

        // Here the list is split by comma into the weaponCVars
        Array<String> weaponCVars;
        weaponString.Split(weaponCVars, ",");

        //Console.printf("In slot: "..inCustomSlot);

        // We need a list of weapons in the slot that the player *also* has
        Array<String> currentWeaponsInSlotString;
        Array<Weapon> currentWeaponsInSlotObject;
        // We can also check if the held weapon is in the new slot already
        bool inCustomSlot = false;
        for (int i = 0; i < weaponCVars.Size(); i++)
        {
            // If the player is holding a weapon in the slot
            for (int j = 0; j < currentWeapons.Size(); j++)
            {
                if (weaponCVars[i] == currentWeapons[j].weapon.GetClassName())
                {
                    currentWeaponsInSlotString.Push(currentWeapons[j].weapon.GetClassName());
                    currentWeaponsInSlotObject.Push(currentWeapons[j].weapon);

                    // Check if the held weapon is in the slot
                    if (currentWeapons[j].weapon.GetClassName() == bufferedWeaponString) inCustomSlot = true;
                }
            }
        }

        // If no weapons in the slot, do nothing
        if (currentWeaponsInSlotString.Size() == 0)
        {
            // Show the empty preview if needed
            if (LSS_PreviewOnWeaponSwap && LSS_PreviewOnWeaponSwapSlotEmpty)
            {
                int slotIndex = (slot > 0) ? slot - 1 : 9;

                slotTimers[slotIndex] = (LSS_PreviewTimer + LSS_PreviewTimerFade) * 35;

                // Highlight nothing
                highlightedSlot = (-1, -1);
            }

            // Do nothing
            return;
        }

        // If the weapon is in the slot already, then switch to the next weapon (if there is one)
        int weaponIndex = 0;
        String networkString;
        if (inCustomSlot)
        {
            // Do nothing if there is only one weapon
            //if (currentWeaponsInSlotString.Size() == 1) return;

            // Find the index of the current weapon
            // Increment by 1 because we want the next weapon
            weaponIndex = currentWeaponsInSlotString.Find(bufferedWeaponString);
            weaponIndex++;

            // If the index matches the size, then it was the last one,
            // so grab the first weapon
            if (weaponIndex == currentWeaponsInSlotString.Size()) weaponIndex = 0;

            // If LSS_RememberLastWeaponInSlot = true, then
            // move the current weapon in the CVar to the end
            if (LSS_RememberLastWeaponInSlot)
            {
                CVar slotCVar = CVar.GetCVar("LSS_Slot"..slot, players[ConsolePlayer]);
                int slotCVarIndex = slotCVar.GetString().IndexOf(bufferedWeaponString);
                String heldWeaponString = bufferedWeaponString;
                slotCVar.SetString(
                    slotCVar.GetString().Left(slotCVarIndex)..
                    slotCVar.GetString().Mid(slotCVarIndex + bufferedWeaponString.Length() + 1)..
                    bufferedWeaponString..","
                );

                UpdateCurrentWeaponsArray();
                SaveCurrentWeaponsToDisk();
            }
            String newWeaponString = currentWeaponsInSlotString[weaponIndex];

            // Print out a hudmessage
            //HUDMessageBase message = new HUDMessageBase("Message");
            //StatusBar.AttachMessage(message);

            // Finally switch weapons
            bufferedWeaponString = newWeaponString;
            networkString = "LSS_WeaponSwitchTo"..newWeaponString;
        }
        // If not, then switch to the first weapon in the new slot
        else
        {
            //Console.printf(currentWeaponsInSlotString[0]);
            bufferedWeaponString = currentWeaponsInSlotString[0];
            networkString = "LSS_WeaponSwitchTo"..currentWeaponsInSlotString[0];
        }

        // Only do stuff if it's a different weapon
        if (players[ConsolePlayer].ReadyWeapon != null &&
            players[ConsolePlayer].ReadyWeapon.GetClassName() != bufferedWeaponString)
        {
            // Set the last used weapon
            lastUsedWeapon = players[ConsolePlayer].ReadyWeapon;

            // Send the network event to everyone
            SendNetworkEvent(networkString);

            // Display the name of the weapon on the bottom of the screen
            currentWeaponsInSlotObject[weaponIndex].DisplayNameTag();
        }

        // Enable the preview
        if (LSS_PreviewOnWeaponSwap)
        {
            int slotIndex = (slot > 0) ? slot - 1 : 9;

            slotTimers[slotIndex] = (LSS_PreviewTimer + LSS_PreviewTimerFade) * 35;

            // Set the highlighted slot
            highlightedSlot = (slotIndex, weaponIndex);
        }
    }

    ui void PlayerLastWeaponChange()
    {
        bool hasLastUsedWeapon = false;
        int weaponIndex;

        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            if (currentWeapons[i] != null &&
                currentWeapons[i].weapon.GetClassName() == lastUsedWeapon.GetClassName())
            {
                hasLastUsedWeapon = true;
                weaponIndex = i;
                break;
            }
        }

        if (!hasLastUsedWeapon) return;

        // Send to network
        SendNetworkEvent("LSS_WeaponSwitchTo"..lastUsedWeapon.GetClassName());

        // Display the name of the weapon on the bottom of the screen
        currentWeapons[weaponIndex].weapon.DisplayNameTag();

        // Set to held weapon
        lastUsedWeapon = players[ConsolePlayer].ReadyWeapon;

        // Set the fade
        slotTimers[currentWeapons[weaponIndex].slot] = (LSS_PreviewTimer + LSS_PreviewTimerFade) * 35;
        // Set the highlighted slot
        highlightedSlot = (currentWeapons[weaponIndex].slot, currentWeapons[weaponIndex].row);
    }

    /***
    *   Sets up the fade for whenever a new weapon is picked up
    */
    ui void PlayerPickedUpNewWeapon(Array<Weapon> tempWeaponList)
    {
        Array<Weapon> newWeaponList;

        // Refresh the inventory
        UpdateCurrentWeaponsArray();
        SaveCurrentWeaponsToDisk();

        // Check if a new weapon has been picked up.
        // If so, then show the slot it is in.
        for (int i = 0; i < tempWeaponList.Size(); i++)
        {
            // Check if every weapon is the same.
            // If there is a new weapon, then the player had just picked it up.
            if (weaponList.Find(tempWeaponList[i]) == weaponList.Size() && 
                tempWeaponList[i].GetClassName() != "HDIncapWeapon" &&
                tempWeaponList[i].GetClassName() != "SelfBandage")
            {
                //Console.printf("Picked up: %s", tempWeaponList[i].GetClassName());
                newWeaponList.Push(tempWeaponList[i]);
            }
        }

        // Set the slot timers.
        for (int i = 0; i < newWeaponList.Size(); i++)
        {
            // Parse the LSS_Weapons to get the slots
            for (int j = 0; j < currentWeapons.Size(); j++)
            {
                if (currentWeapons[j].Weapon.GetClassName() == newWeaponList[i].GetClassName())
                {
                    //Console.printf("Slot: %i", currentWeapons[j].slot);
                    slotTimers[currentWeapons[j].slot] = (LSS_PreviewTimer + LSS_PreviewTimerFade) * 35;

                    // Set the highlighted slot
                    highlightedSlot = (currentWeapons[j].slot, currentWeapons[j].row);
                }
            }
        }
    }

    /***
    *   Sets up the fade for whenever a weapon is dropped
    */
    ui void PlayerDroppedWeapon(Array<Weapon> tempWeaponList)
    {
        Array<Weapon> droppedWeaponList;

        // Check if a weapon has been dropped
        for (int i = 0; i < weaponList.Size(); i++)
        {
            if (weaponList[i] != null &&
                tempWeaponList.Find(weaponList[i]) == tempWeaponList.Size() &&
                weaponList[i].GetClassName() != "HDIncapWeapon" &&
                weaponList[i].GetClassName() != "SelfBandage")
            {
                //Console.printf("Weapon dropped: %s", weaponList[i].GetClassName());
                droppedWeaponList.Push(weaponList[i]);
            }
        }

        // Set the slot timers.
        for (int i = 0; i < droppedWeaponList.Size(); i++)
        {
            // Null checks
            if (droppedWeaponList[i] == null) continue;

            // Parse the LSS_Weapons to get the slots
            for (int j = 0; j < currentWeapons.Size(); j++)
            {
                // Null checks
                if (currentWeapons[j] == null) continue;

                if (currentWeapons[j].Weapon.GetClassName() == droppedWeaponList[i].GetClassName())
                {
                    //Console.printf("Slot: %i", currentWeapons[j].slot);
                    slotTimers[currentWeapons[j].slot] = (LSS_PreviewTimer + LSS_PreviewTimerFade) * 35;

                    // Set the highlighted slot
                    highlightedSlot = (-1, -1);
                }
            }
        }

        // Refresh the inventory
        UpdateCurrentWeaponsArray();
        SaveCurrentWeaponsToDisk();
    }

    ui void SetColorPreset()
    {
        CVar slotNumberColor = CVar.GetCvar("LSS_SlotNumberColor", players[ConsolePlayer]);
        CVar weaponNameColor = CVar.GetCvar("LSS_WeaponNameColor", players[ConsolePlayer]);
        CVar outerColor = CVar.GetCvar("LSS_OuterColor", players[ConsolePlayer]);
        CVar outerColorAlt = CVar.GetCvar("LSS_OuterColorAlt", players[ConsolePlayer]);
        CVar innerColor = CVar.GetCvar("LSS_InnerColor", players[ConsolePlayer]);
        CVar innerColorAlt = CVar.GetCvar("LSS_InnerColorAlt", players[ConsolePlayer]);
        CVar highlightColor = CVar.GetCvar("LSS_HighlightColor", players[ConsolePlayer]);
        CVar heldWeaponColor = CVar.GetCvar("LSS_HeldWeaponColor", players[ConsolePlayer]);

        // Default
        if (LSS_ColorPreset == 0)
        {
            slotNumberColor.ResetToDefault();
            weaponNameColor.ResetToDefault();
            outerColor.ResetToDefault();
            outerColorAlt.ResetToDefault();
            innerColor.ResetToDefault();
            innerColorAlt.ResetToDefault();
            highlightColor.ResetToDefault();
            heldWeaponColor.ResetToDefault();
        }
        else if (LSS_ColorPreset == 1)
        {
            slotNumberColor.SetInt(9);
            weaponNameColor.SetInt(2);
            outerColor.SetString("ad c7 e7");
            outerColorAlt.SetString("dd c9 af");
            innerColor.SetString("e4 ef ff");
            innerColorAlt.SetString("ff e0 d3");
            highlightColor.SetString("ff ff ff");
            heldWeaponColor.SetString("8b 8b 8b");
        }
        else if (LSS_ColorPreset == 2)
        {
            slotNumberColor.SetInt(12);
            weaponNameColor.SetInt(20);
            outerColor.SetString("15 1b 23");
            outerColorAlt.SetString("1b 1b 1b");
            innerColor.SetString("07 13 1c");
            innerColorAlt.SetString("0b 0b 0b");
            highlightColor.SetString("3b 3b 3b");
            heldWeaponColor.SetString("27 27 27");
        }
        // Trans Flag
        else if (LSS_ColorPreset == 3)
        {
            slotNumberColor.SetInt(9);
            weaponNameColor.SetInt(9);
            outerColor.SetString("00 1b 33");
            outerColorAlt.SetString("33 00 1f");
            innerColor.SetString("5b ce fa");
            innerColorAlt.SetString("f5 a9 b8");
            highlightColor.SetString("ff ff ff");
            heldWeaponColor.SetString("ff ff ff");
        }
        else if (LSS_ColorPreset == 4)
        {
            slotNumberColor.SetInt(9);
            weaponNameColor.SetInt(9);
            outerColor.SetString("2c 2c 2c");
            outerColorAlt.SetString("2c 2c 2c");
            innerColor.SetString("fc f4 34");
            innerColorAlt.SetString("9c 58 d1");
            highlightColor.SetString("ff ff ff");
            heldWeaponColor.SetString("ff ff ff");
        }
    }

    /***
    *   Returns the player that is being viewed through.
    *   Returns yourself if viewing something not a player.
    */
    ui PlayerInfo GetSpyTarget()
    {
        // If spying on another player
        if (players[ConsolePlayer].Camera.player != null)
        {
            return players[ConsolePlayer].Camera.player;
        }
        else
        {
            return players[ConsolePlayer];
        }
    }
}
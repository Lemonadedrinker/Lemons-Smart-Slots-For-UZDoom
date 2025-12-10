class LSS_EventHandler : EventHandler
{
    ui bool isEditing;
    ui Array<LSS_Weapon> currentWeapons;
    ui Vector2 MousePosition;

    ui bool mouseClicked;
    ui Vector2 slotSelected;
    ui bool hasSlotSelected;
    ui String selectedWeaponString;

    ui bool keyDown;

    /**
    * Processes keybinds
    */
    override void ConsoleProcess(ConsoleEvent event)
    {
        if(players[Consoleplayer].mo == null) return;

        // Player switches weapons
        if (event.Name.Left(10) == "LSS_Switch")
        {
            // Trim the digit, convert that to an int
            String digitString = event.Name;
            digitString.Remove(0, 10);
            int slot = digitString.ToInt(10);
            //Console.printf(" Slot: %i", slot);

            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerSlotNumberSelected(slot);
        }
        
        // Player tries to edit
        if (event.Name == "LSS_Edit")
        {
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();
            isEditing = !isEditing;
            // Allow the play scope to know that the player is editing
            if (isEditing)
            {
                slotSelected = (-1, -1);
                hasSlotSelected = false;
                selectedWeaponString = "";
                SendNetworkEvent("LSS_Editing");
            }
            else
            {
                SendNetworkEvent("LSS_NotEditing");
            }

            // Debugging
            //int randomWeaponIndex = crandom(0, currentWeapons.Size() - 1);
            //String randomWeaponName = currentWeapons[randomWeaponIndex].GetClassName();

            //SendNetworkEvent("LSS_WeaponSwitchTo" .. randomWeaponName);
        }

        // Set Color Preset
        if (event.Name == "LSS_SetPreset")
        {
            SetColorPreset();
        }

        // Reset slots
        if (event.Name == "LSS_ResetSlots")
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
            isEditing = false;

            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";

            SendNetworkEvent("LSS_NotEditing");
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
        }

        if (event.Type == UiEvent.Type_KeyUp && UiEvent.Type_Char)
        {
            keyDown = false;
        }

        if (event.Type == event.Type_LButtonDown && mouseClicked == false)
        {
            //Console.printf("Mouse clicked!");
            mouseClicked = true;
        }

        return false;
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
    }

    /***
    * Iterates through the player's inventory, looking for weapons
    */
    ui void UpdateCurrentWeaponsArray()
    {
        Let player = players[Consoleplayer];
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

            // Vanilla Doom weapons need to be hardcoded because ZDoom does not
            // automatically assign slots to them (I think)
            if (playerWeapon.GetClassName() == 'Fist' || playerWeapon.GetClassName() == 'Chainsaw') defaultSlot = 1;
            else if (playerWeapon.GetClassName() == 'Pistol') defaultSlot = 2;
            else if (playerWeapon.GetClassName() == 'Shotgun' || playerWeapon.GetClassName() == 'SuperShotgun') defaultSlot = 3;
            else if (playerWeapon.GetClassName() == 'Chaingun') defaultSlot = 4;
            else if (playerWeapon.GetClassName() == 'RocketLauncher') defaultSlot = 5;
            else if (playerWeapon.GetClassName() == 'PlasmaRifle') defaultSlot = 6;
            else if (playerWeapon.GetClassName() == 'BFG9000') defaultSlot = 7;
            //else if (playerWeapon.GetClassName() == 'ID24Incinerator') defaultSlot = 8;
            //else if (playerWeapon.GetClassName() == 'ID24CalamityBlade') defaultSlot = 9;

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
            tempWeapon.slot = storedSlot;

            tempWeapon.row = row[tempWeapon.slot];
            row[tempWeapon.slot]++;

            //Console.printf(" Temp weapon2: "..tempWeapon.weapon.GetClassName());

            //Console.printf(tempWeapon.weapon.GetClassName().." stored in slot index %i", tempWeapon.slot);

            // Finally add to the array
            currentWeapons.Push(tempWeapon);
        }
    }

    /***
    *   Checks if the weapons in currentWeapons are in the CVars
    *   If so, do nothing
    *   If not, then save it to the disk
    */
    ui void SaveCurrentWeaponsToDisk()
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

    /***
    *   Translates a slot number into a weapon to switch to
    *   The weapon is sent over the network to every client
    */
    ui void PlayerSlotNumberSelected(int slot)
    {
        // The player's current held weapon
        Weapon heldWeapon = players[Consoleplayer].ReadyWeapon;

        // This is the list of weapons for the slot
        String weaponString = CVar.GetCvar("LSS_Slot"..slot, players[ConsolePlayer]).GetString();

        // Here the list is split by comma into the weaponCVars
        Array<String> weaponCVars;
        weaponString.Split(weaponCVars, ",");

        //Console.printf("In slot: "..inCustomSlot);

        // We need a list of weapons in the slot that the player *also* has
        Array<String> currentWeaponsInSlot;
        // We can also check if the held weapon is in the new slot already
        bool inCustomSlot = false;
        for (int i = 0; i < weaponCVars.Size(); i++)
        {
            // If the player is holding a weapon in the slot
            for (int j = 0; j < currentWeapons.Size(); j++)
            {
                if (weaponCVars[i] == currentWeapons[j].weapon.GetClassName())
                {
                    currentWeaponsInSlot.Push(currentWeapons[j].weapon.GetClassName());

                    // Check if the held weapon is in the slot
                    if (currentWeapons[j].weapon.GetClassName() == heldWeapon.GetClassName()) inCustomSlot = true;
                }
            }
        }

        // If no weapons in the slot, do nothing
        if (currentWeaponsInSlot.Size() == 0) return;

        // If the weapon is in the slot already, then switch to the next weapon (if there is one)
        if (inCustomSlot)
        {
            // Do nothing if there is only one weapon
            if (currentWeaponsInSlot.Size() == 1) return;

            // Find the index of the current weapon
            // Increment by 1 because we want the next weapon
            int weaponIndex = currentWeaponsInSlot.Find(heldWeapon.GetClassName());
            weaponIndex++;

            // If the index matches the size, then it was the last one,
            // so grab the first weapon
            if (weaponIndex == currentWeaponsInSlot.Size()) weaponIndex = 0;

            // If LSS_RememberLastWeaponInSlot = true, then
            // move the current weapon in the CVar to the end
            if (LSS_RememberLastWeaponInSlot)
            {
                CVar slotCVar = CVar.GetCVar("LSS_Slot"..slot, players[ConsolePlayer]);
                int slotCVarIndex = slotCVar.GetString().IndexOf(heldWeapon.GetClassName());
                String heldWeaponString = heldWeapon.GetClassName();
                slotCVar.SetString(
                    slotCVar.GetString().Left(slotCVarIndex)..
                    slotCVar.GetString().Mid(slotCVarIndex + heldWeaponString.Length() + 1)..
                    heldWeapon.GetClassName()..","
                );

                UpdateCurrentWeaponsArray();
                SaveCurrentWeaponsToDisk();
            }

            // Finally switch weapons
            SendNetworkEvent("LSS_WeaponSwitchTo"..currentWeaponsInSlot[weaponIndex]);
        }
        // If not, then switch to the first weapon in the new slot
        else
        {
            //Console.printf(currentWeaponsInSlot[0]);
            SendNetworkEvent("LSS_WeaponSwitchTo"..currentWeaponsInSlot[0]);
        }
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
        // Trans Flag
        else if (LSS_ColorPreset == 1)
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
    }
}
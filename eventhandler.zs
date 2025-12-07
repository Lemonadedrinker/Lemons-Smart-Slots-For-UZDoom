class LCS_EventHandler : EventHandler
{
    ui bool isEditing;
    ui Array<LCS_Weapon> currentWeapons;
    ui Vector2 MousePosition;

    ui bool mouseClicked;
    ui Vector2 slotSelected;
    ui bool hasSlotSelected;
    ui String selectedWeaponString;

    ui bool needsWeaponUpdate;

    /**
    * Processes keybinds
    */
    override void ConsoleProcess(ConsoleEvent event)
    {
        if(players[Consoleplayer].mo == null) return;

        // Player switches weapons
        if (event.Name.Left(10) == "LCS_Switch")
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
        if (event.Name == "LCS_Edit")
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
                SendNetworkEvent("LCS_Editing");
            }
            else
            {
                SendNetworkEvent("LCS_NotEditing");
            }

            // Debugging
            //int randomWeaponIndex = crandom(0, currentWeapons.Size() - 1);
            //String randomWeaponName = currentWeapons[randomWeaponIndex].GetClassName();

            //SendNetworkEvent("LCS_WeaponSwitchTo" .. randomWeaponName);
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

            SendNetworkEvent("LCS_NotEditing");
        }

        // Getting mouse inputs
        if (event.MouseX != 0 && event.MouseY != 0)
        {
            MousePosition = (event.MouseX, event.MouseY);
        }

        // Try to switch weapons
        int keyChar = event.KeyChar;
        //Console.printf("%i", keyChar);
        if (keyChar > 47 && keyChar < 58)
        {
            int slot = keyChar - 48;
            int weaponSlot = (slot != 0) ? slot : 0;
            //Console.printf(" slot: %i, weaponSlot: %i", slot, weaponSlot);

            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();

            PlayerSlotNumberSelected(weaponSlot);
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

        if (event.Name.Left(18) == "LCS_WeaponSwitchTo")
        {
            String weaponName = event.Name;
            weaponName.Remove(0, 18);

            //Console.printf("%s", weaponName);
            player.mo.A_SelectWeapon(weaponName);
        }

        // *Need* to only enable the UI for the player that started editing
        // Should be safe for multiplayer
        else if (event.Name == "LCS_Editing" && player == players[ConsolePlayer])
        {
            self.IsUiProcessor = true;
            self.RequireMouse = true;
        }
        else if (event.Name == "LCS_NotEditing" && player == players[ConsolePlayer])
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
        Array<LCS_Weapon> tempWeaponArray;
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

            // Check if the item is on slots 0-9
            if ((defaultSlot < 0) || (defaultSlot > 9)) continue;
            
            // Weapon found!!
            let newWeapon = new('LCS_Weapon');
            newWeapon.weapon = playerWeapon;

            tempWeaponArray.Push(newWeapon);
            //Console.printf(" HAVE: " .. newWeapon.weapon.GetClassName() .. " in slot #" .. defaultSlot .. " and priority: " .. priority);
        }

        // Now we parse through the CVars to precompute the slots and priorities
        currentWeapons.Clear();
        int row[10];
        LCS_Weapon tempWeapon;

        for (int slot = 0; slot < 10; slot++)
        {
            int currentSlot = (slot == 9) ? 0 : slot + 1;

            // This is the list of weapons for the slot
            String savedWeaponString = CVar.GetCvar("LCS_Slot"..currentSlot, players[ConsolePlayer]).GetString();
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
            
            // Vanilla Doom weapons need to be hardcoded because ZDoom does not
            // automatically assign slots to them (I think)
            if (tempWeapon.GetClassName() == 'Fist' || tempWeapon.GetClassName() == 'Chainsaw') tempWeapon.row = 0;
            else if (tempWeapon.GetClassName() == 'Pistol') tempWeapon.row = 1;
            else if (tempWeapon.GetClassName() == 'Shotgun' || tempWeapon.GetClassName() == 'SuperShotgun') tempWeapon.row = 2;
            else if (tempWeapon.GetClassName() == 'Chaingun') tempWeapon.row = 3;
            else if (tempWeapon.GetClassName() == 'RocketLauncher') tempWeapon.row = 4;
            else if (tempWeapon.GetClassName() == 'PlasmaRifle') tempWeapon.row = 5;
            else if (tempWeapon.GetClassName() == 'BFG9000') tempWeapon.row = 6;
            else
            {
                int storedSlot = (tempWeapon.weapon.SlotNumber != 0) ? tempWeapon.weapon.SlotNumber - 1 : 9;
                tempWeapon.slot = storedSlot;
            }

            tempWeapon.row = row[tempWeapon.weapon.SlotNumber];
            row[tempWeapon.weapon.SlotNumber]++;

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
                // LCS_Slot2=Pistol,Shotgun,Chaingun,
                // LCS_Slot3=BFG9000,

                // This is the list of weapons for the slot
                currentSlot = (slot == 9) ? 0 : slot + 1;
                String weaponString = CVar.GetCvar("LCS_Slot"..currentSlot, players[ConsolePlayer]).GetString();
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
                CVar toSave = CVar.GetCvar("LCS_Slot"..currentSlot, players[ConsolePlayer]);

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
        String weaponString = CVar.GetCvar("LCS_Slot"..slot, players[ConsolePlayer]).GetString();

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

            // Finally switch weapons
            SendNetworkEvent("LCS_WeaponSwitchTo"..currentWeaponsInSlot[weaponIndex]);
        }
        // If not, then switch to the first weapon in the new slot
        else
        {
            //Console.printf(currentWeaponsInSlot[0]);
            SendNetworkEvent("LCS_WeaponSwitchTo"..currentWeaponsInSlot[0]);
        }
    }
}
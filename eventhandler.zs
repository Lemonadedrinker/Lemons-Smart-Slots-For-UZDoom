class LCS_EventHandler : EventHandler
{
    ui bool isEditing;
    ui Array<LCS_Weapon> currentWeapons;
    ui Vector2 MousePosition;

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

            SlotSelected(slot);
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
            SendNetworkEvent("LCS_NotEditing");
        }

        // Getting mouse inputs
        if (event.MouseX != 0 && event.MouseY != 0)
        {
            MousePosition = (event.MouseX, event.MouseY);
        }

        /*
        // Used to catch any keys that should disable the user interface
        Array<Int> boundKeys;
        Bindings.GetAllKeysForCommand(boundKeys, "event LCS_Edit");
        bool exitKeyPressed = false;
        
        // Check if the keybind was pressed
        // Also should handle if there are no bound keys
        for (int i = 0; i < boundKeys.Size(); i++)
        {
            //Console.printf("Key pressed: %i and Bound Key: %s", event.KeyScan, Bindings.GetBinding(boundKeys[i]));
            if (event.KeyChar == boundKeys[i]) exitKeyPressed = true;
        }

        // Hardcoded 27 is ASCII for the esc key as well as
        // whatever keybinds the user has bound
        if (event.KeyChar == 27 || exitKeyPressed)
        {
            isEditing = false;
            SendNetworkEvent("LCS_NotEditing");
        }
        */

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

            Console.printf("%s", weaponName);
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
        currentWeapons.Clear();
        int slot = -1;
        int priority;
        // GZDoom's inventory can be parsed through as a linked list, where
        // Inv is the next item in the list.
        for (let item = player.mo.Inv; item != null; item = item.Inv)
        {
            // Cast item as a weapon
            let playerWeapon = Weapon(item);

            // If the cast fails, keep going
            if (!playerWeapon) continue;

            slot = playerWeapon.SlotNumber;

            // Vanilla Doom weapons need to be hardcoded because ZDoom does not
            // automatically assign slots to them (I think)
            if(playerWeapon is 'Fist' || playerWeapon is 'Chainsaw') slot = 1;
            else if (playerWeapon is 'Pistol') slot = 2;
            else if (playerWeapon is 'Shotgun' || playerWeapon is 'SuperShotgun') slot = 3;
            else if (playerWeapon is 'Chaingun') slot = 4;
            else if (playerWeapon is 'RocketLauncher') slot = 5;
            else if (playerWeapon is 'PlasmaRifle') slot = 6;
            else if (playerWeapon is 'BFG9000') slot = 7;

            // Check if the item is on slots 0-9
            if ((slot < 0) || (slot > 9)) continue;
            
            // Weapon found!!
            let newWeapon = new('LCS_Weapon');
            newWeapon.weapon = playerWeapon;
            newWeapon.slot = slot;

            currentWeapons.Push(newWeapon);
            //Console.printf(" HAVE: " .. weapon.GetClassName() .. " in slot #" .. slot .. " and priority: " .. priority);
        }
    }

    /***
    *   Checks if the weapons in currentWeapons are in the CVars
    *   If so, do nothing
    *   If not, then save it to the disk
    */
    ui void SaveCurrentWeaponsToDisk()
    {
        // Check for each weapon
        for (let weaponIndex = 0; weaponIndex < currentWeapons.Size(); weaponIndex++)
        {
            // First we check if the weapons are saved
            bool isSaved = false;
            for (int slot = 0; slot < 10; slot++)
            {
                // The slots are saved as follows:
                // LCS_Slot2=Pistol,Shotgun,Chaingun,
                // LCS_Slot3=BFG9000,

                // This is the list of weapons for the slot
                String weaponString = CVar.GetCvar("LCS_Slot"..slot, players[ConsolePlayer]).GetString();
                //Console.printf(weaponString);

                // Here the list is split by comma into the weaponCVars
                Array<String> weaponCVars;
                weaponString.Split(weaponCVars, ",");

                // Check if the weapon is in the list
                if (weaponCVars.Find(currentWeapons[weaponIndex].weapon.GetClassName()) != weaponCVars.Size())
                {
                    //Console.printf("Weapon found!!");
                    isSaved = true;
                    break;
                }
            }

            // If not saved, then we save them
            if (!isSaved)
            {
                // Read the existing cvar
                CVar toSave = CVar.GetCvar("LCS_Slot"..currentWeapons[weaponIndex].slot, players[ConsolePlayer]);

                // Override it, appending the new weapon to the end
                toSave.SetString(""..toSave.GetString()..currentWeapons[weaponIndex].weapon.GetClassName()..",");
            }
        }
    }

    /***
    *   Translates a slot number into a weapon to switch to
    *   The weapon is sent over the network to every client
    */
    ui void SlotSelected(int slot)
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
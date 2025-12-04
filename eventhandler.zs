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
        
        if (event.Name == "LCS_Edit")
        {
            LCSUpdateCurrentWeapons();
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

    /***
    * Iterates through the player's inventory, looking for weapons
    */
    ui void LCSUpdateCurrentWeapons()
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
}
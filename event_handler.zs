class lcs_EventHandler : EventHandler
{
    private ui bool editing;
    Array<Weapon> currentWeapons;

    /**
    * Processes keybinds
    */
    override void ConsoleProcess(ConsoleEvent e)
    {
        if(players[Consoleplayer].mo == null) return;
        let playerInventory = players[Consoleplayer].ReadyWeapon.GetClassName();
        
        if (e.Name == "LCS_Edit")
        {
            //Console.MidPrint(smallfont, String.Format("%suwu", "\cg"));
            editing = !editing;

            self.IsUiProcessor = editing;
            self.RequireMouse = editing;

            Console.MidPrint(smallfont, String.Format("%s" .. playerInventory, "\cg"));


            // From https://forum.zdoom.org/viewtopic.php?t=79042
            // Creates an array of weapons that the player currently has

            for (let i = 0; i < 10; i++)
            {
                let player = players[Consoleplayer];
                let iSize = player.weapons.SlotSize(i);
                for (let x = 0; x < iSize; x++)
                    {
                        let wclassType = player.weapons.GetWeapon(i,x);
                        let wclassName = wclassType.GetClassName();
                        //Console.printf(" Weapon:" .. i .. ", ".. x .. " " .. wclassName);

                        // Check if the player has the weapon
                        if (player.weapons.LocateWeapon(wclassType))
                        {
                            Console.printf(" HAVE:" .. wclassType.GetClassName());
                        }
                    }
		    }
        }
    }

    override bool UiProcess(UiEvent e)
    {
        return false;
    }
}
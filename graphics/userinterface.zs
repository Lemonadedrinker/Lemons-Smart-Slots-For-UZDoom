extend class LCS_EventHandler
{
    ui Vector2 HudScale;
    ui Color outerColor;
    ui Color innerColor;
    ui Color highlightColor;

    ui Vector2 mouseSlot;

    ui int scalingFactor;
    ui int boxWidth;
    ui int boxHeight;
    ui int bevel;
    ui int fontColor;

    override void RenderOverlay(RenderEvent event)
    {
        if (!isEditing)
        {
            return;
        }

        outerColor = Color(35, 32, 33);
        innerColor = Color(97, 90, 92);
        highlightColor = Color(191, 177, 182);

        int a, b, screenWidth, d; 
        [a, b, screenWidth, d] = Screen.GetViewWindow();
        scalingFactor = screenWidth / 480;

        boxWidth = 48 * scalingFactor;
        boxHeight = 40 * scalingFactor;
        bevel = 1 * scalingFactor;
        fontColor = Font.CR_RED;

        HudScale = StatusBar.GetHUDScale();
        //Screen.DrawThickLine(MousePosition.X, MousePosition.Y, 10, 10, HudScale.X, Color(255, 0, 255));
        //DrawBox((MousePosition.X, MousePosition.Y), boxWidth, boxHeight, bevel);

        // Draw the empty frame
        DrawFrame();

        // Calculate which slot should have been clicked on
        mouseSlot = CalculateSlotUnderMouse();

        // Need to alternate
        if (mouseClicked) 
        {
            mouseClicked = false;
            // Calculate if it was a valid click
            if (!hasSlotSelected) CalculateMouseClick(mouseSlot.X, mouseSlot.Y);
            
            // Replace the slot
            else ReplaceSlot(mouseSlot.X, mouseSlot.Y);
        }
        
        DrawWeaponBoxes();


    }

    private ui void DrawBox(Vector2 origin, int width, int height, int bevel, bool highlighted = false)
    {
        // Outer square
        DrawSquare(origin, width, height, outerColor);

        // Inner one, needs an offset
        Vector2 innerOffset = (origin.X, origin.Y);

        Color insideColor = highlighted ? highlightColor : innerColor;
        DrawSquare(innerOffset, width - 4 * bevel, height - 4 * bevel, insideColor);
    }

    // Code copied from example at
    // https://zdoom.org/wiki/Classes:Shape2D
    private ui void DrawSquare(Vector2 origin, int width, int height, Color squareColor)
    {
        // Create our square
        let square = new("Shape2D");

        // Set the vertices of the square (corresponds to a location on the screen)
        // This square is centered at the origin of the screen and each side has a length of 1, making it great for scaling
        square.PushVertex((-0.5,-0.5));
        square.PushVertex((0.5,-0.5));
        square.PushVertex((0.5,0.5));
        square.PushVertex((-0.5,0.5));

        // Set the uv coordinates of the texture (defines which point of the texture maps to which vertex)
        square.PushCoord((0,0));
        square.PushCoord((1,0));
        square.PushCoord((1,1));
        square.PushCoord((0,1));

        // Set the triangles of the square using the vertex indices (creates a surface to draw the texture on)
        square.PushTriangle(0,1,2);
        square.PushTriangle(0,2,3);

        // Now the we have our square set up, let's scale it and draw it somewhere else on the screen

        // Create the transformer
        let transformation = new("Shape2DTransform");

        // Note: order is important here! You should always scale first, rotate second, and translate last to ensure your shape changes how you expect it to
        transformation.Scale((width, height)); // Scale the square
        //transformation.Rotate(90); // Rotate the square by 90 degrees clockwise
        transformation.Translate((origin.X, origin.Y)); // Move the shape

        // Apply the transformation to our square
        square.SetTransform(transformation);

        Screen.DrawShapeFill(squareColor, 1, square);
    }

    private ui void DrawFrame()
    {
        for (int i = 0; i < 10; i++)
        {
            // Draw each box for the numbers
            DrawBox((i * boxWidth + (boxWidth / 2), boxHeight / 4), boxWidth, boxHeight / 2, bevel);

            // Digits are 1-9 and 0
            int digit = (i == 9) ? 0 : i + 1;

            Screen.DrawText(
                OriginalSmallFont, 
                fontColor, 
                i * boxWidth + (boxWidth / 2) - scalingFactor * 8, 
                boxHeight / 4 - scalingFactor * 7, 
                ""..(digit),
                DTA_ScaleX, scalingFactor * 2,
                DTA_ScaleY, scalingFactor * 2
            );
        }
    }

    private ui Vector2 CalculateSlotUnderMouse()
    {
        //Console.printf("%i, %i", MousePosition.X, MousePosition.Y);

        // Scaled to the screen
        int xPosition = MousePosition.X / boxWidth;
        int yPosition = (MousePosition.Y - (boxHeight / 2)) / boxHeight;

        // Remove if y position is higher than it should be
        if (MousePosition.Y <= boxHeight / 2)
        {
            xPosition = -1;
            yPosition = -1;
        }

        //Console.printf("%i, %i", xPosition, yPosition);

        return (xPosition, yPosition);
    }

    private ui void DrawWeaponBoxes()
    {
        // Draw the selected weapon last so it's on top
        Vector2 weaponBoxOnCursorPosition = (-1, -1);
        int selectedWeaponIndex = -1;

        LCS_Weapon selectedWeaponObject;

        for (int slot = 0; slot < 10; slot++)
        {
            int row = 0;
            int weaponsInSlot = 0;
            int currentSlot = (slot == 9) ? 0 : slot + 1;

            /*
            for (int j = 0; j < currentWeapons.Size(); j++)
            {
                if (currentWeapons[j].slot == currentSlot)
                {
                    // Highlight the slot if the cursor is underneath it
                    bool highlighted = (i == mouseSlot.X && row == mouseSlot.Y);

                    DrawWeaponBox(i, row, currentWeapons[j], highlighted);
                    row++;
                }
            }
            */
            
            // This is the list of weapons for the slot
            String savedWeaponString = CVar.GetCvar("LCS_Slot"..currentSlot, players[ConsolePlayer]).GetString();
            //Console.printf(weaponString);

            // Here the list is split by comma into the weaponList
            Array<String> savedWeaponList;
            savedWeaponString.Split(savedWeaponList, ",");

            // Check each saved weapon in the comma separated list
            
            for (int savedWeapon = 0; savedWeapon < savedWeaponList.Size(); savedWeapon++)
            {
                // See if the saved weapon is a currently held weapon
                for (int i = 0; i < currentWeapons.Size(); i++)
                {
                    if (savedWeaponList[savedWeapon] == currentWeapons[i].weapon.GetClassName())
                    {
                        // If the mouse is hovering over this slot, then skip the row
                        // This gives the effect of creating a gap to place the new weapon
                        if (hasSlotSelected && mouseSlot == (slot, weaponsInSlot) && slotSelected != mouseSlot)
                        {
                            row++;
                        }

                        // Highlight the slot if the cursor is underneath it
                        bool isHoveredOver = (slot == mouseSlot.X && row == mouseSlot.Y);

                        // Check if the slot was clicked on
                        if (selectedWeaponString == savedWeaponList[savedWeapon])
                        {
                            //Console.printf("Slot selected");
                            //DrawWeaponBoxOnCursor(currentWeapons[i], true);
                            // Save the position so that we can draw it last
                            weaponBoxOnCursorPosition = (slot, row);
                            selectedWeaponObject = currentWeapons[i];
                            //weaponsInSlot--;
                            // Add a gap for the selected weapon only for the slot
                            if (slot == mouseSlot.X && row == mouseSlot.Y) row++;
                            continue;
                        }
                        else
                        {
                            DrawWeaponBox(slot, row, currentWeapons[i], isHoveredOver);
                        }

                        row++;
                        weaponsInSlot++;
                    }
                }
            }
        }

        // Draw the weapon on the cursor if there is one
        if (hasSlotSelected) 
        {
            DrawWeaponBoxOnCursor(selectedWeaponObject, true);
        }
    }

    private ui void DrawWeaponBox(int slot, int row, LCS_Weapon currentWeapon, bool highlighted = false)
    {
        // Draw the box first,
        // then draw the weapon sprite,
        // finally, draw the text over the sprite
        DrawBox(
            ((boxWidth * slot) + (boxWidth / 2),
            (boxHeight * (row + 1))),
            boxWidth,
            boxHeight,
            bevel,
            highlighted
        );

        Screen.DrawTexture(
            currentWeapon.weapon.FindState("Spawn", true).GetSpriteTexture(0, 0, (0, 0)),
            true,
            (boxWidth * slot) + (boxWidth / 2),
            (boxHeight * (row + 1) + (boxHeight / 6)),
            DTA_ScaleX, scalingFactor * 1,
            DTA_ScaleY, scalingFactor * 1
        );

        Screen.DrawText(
            OriginalSmallFont, 
            fontColor, 
            slot * boxWidth + 2 * bevel, 
            (row + 1.3) * boxHeight, 
            currentWeapon.weapon.GetClassName(),
            DTA_ScaleX, scalingFactor / 2,
            DTA_ScaleY, scalingFactor / 2,
            DTA_TextLen, 11
        );
    }

    private ui void DrawWeaponBoxOnCursor(LCS_Weapon currentWeapon, bool highlighted = true)
    {
        // Draw the box first,
        // then draw the weapon sprite,
        // finally, draw the text over the sprite
        DrawBox(
            (MousePosition.X,
            MousePosition.Y),
            boxWidth,
            boxHeight,
            bevel,
            highlighted
        );

        Screen.DrawTexture(
            currentWeapon.weapon.FindState("Spawn", true).GetSpriteTexture(0, 0, (0, 0)),
            true,
            MousePosition.X,
            MousePosition.Y + (boxHeight / 6),
            DTA_ScaleX, scalingFactor * 1,
            DTA_ScaleY, scalingFactor * 1
        );

        Screen.DrawText(
            OriginalSmallFont, 
            fontColor, 
            MousePosition.X - (boxWidth / 2) + (2 * bevel), 
            MousePosition.Y + (.3) * boxHeight, 
            currentWeapon.weapon.GetClassName(),
            DTA_ScaleX, scalingFactor / 2,
            DTA_ScaleY, scalingFactor / 2,
            DTA_TextLen, 11
        );
    }

    private ui void CalculateMouseClick(int slotNumber, int slotRow)
    {
        int oldCurrentSlot = (slotNumber == 9) ? 0 : slotNumber + 1;

        // This is the list of weapons for the slots
        CVar oldCVar = CVar.GetCvar("LCS_Slot"..oldCurrentSlot, players[ConsolePlayer]);

        // Here the list is split by comma into the weaponCVars
        Array<String> oldSlotWeaponCVars;
        oldCVar.GetString().Split(oldSlotWeaponCVars, ",");

        // Need currentWeapons as a string
        Array<String> currentWeaponStrings;
        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            //Console.printf("Current weapons: "..currentWeapons[i].weapon.GetClassName());
            currentWeaponStrings.push(currentWeapons[i].weapon.GetClassName());
        }

        // Separate out only the weapons the player currently has
        Array<String> oldSlotCurrentWeapons;
        for (int i = 0; i < oldSlotWeaponCVars.Size(); i++)
        {
            if (currentWeaponStrings.Find(oldSlotWeaponCVars[i]) != currentWeaponStrings.Size())
            {
                //Console.printf("Old weapon:" .. oldSlotWeaponCVars[i]);
                oldSlotCurrentWeapons.push(oldSlotWeaponCVars[i]);
            }
        }

        //Console.printf("Column size: %i", oldSlotCurrentWeapons.Size());

        if (slotRow < oldSlotCurrentWeapons.Size())
        {
            slotSelected = (slotNumber, slotRow);
            hasSlotSelected = true;
            selectedWeaponString = oldSlotCurrentWeapons[slotRow];
            //Console.printf(" selectedWeaponString: "..selectedWeaponString);
        }
        else
        {
            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";
        }
    }

    /***
    *   Inserts the weapon into the slot, pushing the others around
    */
    private ui void ReplaceSlot(int slotNumber, int slotRow)
    {
        // Clicked out of bounds, nothing happens
        if (mouseSlot == (-1, -1))
        {
            return;
        }

        // Clicked the same slot, set it down and do nothing else
        if ((slotNumber, slotRow) == slotSelected)
        {
            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";
            Console.printf("Nothing happened...");
            return;
        }

        int oldCurrentSlot = (slotSelected.X == 9) ? 0 : slotSelected.X + 1;
        int newCurrentSlot = (slotNumber == 9) ? 0 : slotNumber + 1;

        Console.printf(" oldslot: %i, newslot: %i", oldCurrentSlot, newCurrentSlot);

        // This is the list of weapons for the slots
        CVar oldCVar = CVar.GetCvar("LCS_Slot"..oldCurrentSlot, players[ConsolePlayer]);
        CVar newCVar = CVar.GetCvar("LCS_Slot"..newcurrentSlot, players[ConsolePlayer]);

        // Here the list is split by comma into the weaponCVars
        Array<String> oldSlotWeaponCVars;
        oldCVar.GetString().Split(oldSlotWeaponCVars, ",");
        Array<String> newSlotWeaponCVars;
        newCVar.GetString().Split(newSlotWeaponCVars, ",");

        // Need currentWeapons as a string
        Array<String> currentWeaponStrings;
        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            //Console.printf("Current weapons: "..currentWeapons[i].weapon.GetClassName());
            currentWeaponStrings.push(currentWeapons[i].weapon.GetClassName());
        }

        // Separate out only the weapons the player currently has
        Array<String> oldSlotCurrentWeapons;
        for (int i = 0; i < oldSlotWeaponCVars.Size(); i++)
        {
            if (currentWeaponStrings.Find(oldSlotWeaponCVars[i]) != currentWeaponStrings.Size())
            {
                Console.printf("Old slot weapon: " .. oldSlotWeaponCVars[i]);

                oldSlotCurrentWeapons.push(oldSlotWeaponCVars[i]);
            }
        }

        Array<String> newSlotCurrentWeapons;
        for (int i = 0; i < newSlotWeaponCVars.Size(); i++)
        {
            if (currentWeaponStrings.Find(newSlotWeaponCVars[i]) != currentWeaponStrings.Size())
            {
                Console.printf("New weapon:" .. newSlotWeaponCVars[i]);
                newSlotCurrentWeapons.push(newSlotWeaponCVars[i]);
            }
        }

        // Determine the indices
        // The old index is where the weapon is removed in the cvar,
        // the new one is where the weapon is added

        int newIndex;
        if (slotNumber > newSlotCurrentWeapons.Size())
        {
            newIndex = newSlotCurrentWeapons.Size();
        }
        else
        {
            newIndex = slotNumber;
        }

        // Now create the strings to replace the CVars
        String newString;
        for (int i = 0; i < newSlotCurrentWeapons.Size(); i++)
        {
            newString = newSlotCurrentWeapons[i];
        }
        Console.printf(newString);
        //newCVar.setString(newString);

        newCVar.SetString(newCVar.GetString()..selectedWeaponString..",");

        // Delete the old CVar
        // Need the index
        int oldIndex = oldCVar.getString().IndexOf(selectedWeaponString);

        // Delete the weapon at the index
        String newOldString = oldCVar.GetString();
        newOldString.Remove(oldIndex, selectedWeaponString.Length() + 1);
        oldCVar.SetString(newOldString);

        // Refresh the screen
        needsWeaponUpdate = true;
        slotSelected = (-1, -1);
        hasSlotSelected = false;
        selectedWeaponString = "";
    }
}
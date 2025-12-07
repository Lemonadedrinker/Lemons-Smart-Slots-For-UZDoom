extend class LCS_EventHandler
{
    ui Vector2 HudScale;

    ui float alphaValue;
    ui Color outerColor;
    ui Color transOuterColor;
    ui Color innerColor;
    ui Color highlightColor;
    ui Color heldWeaponColor;

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

        alphaValue = 0.4;

        outerColor = Color(35, 32, 33);
        innerColor = Color(97, 90, 92);
        
        highlightColor = Color(191, 177, 182);
        heldWeaponColor = Color(157, 142, 148);

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
        
        // TODO:
        // Precalculate the weapons that the player currently has
        // The only thing to do every frame is draw the boxes
        DrawWeaponBoxes();
    }

    private ui void DrawBox(Vector2 origin, int width, int height, int bevel, Color color1, Color color2, float alphaValue)
    {
        // Outer square
        DrawSquare(origin, width, height, color1, alphaValue);

        // Inner one, needs an offset
        Vector2 innerOffset = (origin.X, origin.Y);

        DrawSquare(innerOffset, width - 4 * bevel, height - 4 * bevel, color2, alphaValue);
    }

    // Code copied from example at
    // https://zdoom.org/wiki/Classes:Shape2D
    private ui void DrawSquare(Vector2 origin, int width, int height, Color squareColor, float alphaValue)
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

        Screen.DrawShapeFill(squareColor, alphaValue, square);
    }

    private ui void DrawFrame()
    {
        for (int i = 0; i < 10; i++)
        {
            // Draw each box for the numbers
            DrawBox((i * boxWidth + (boxWidth / 2), boxHeight / 4), boxWidth, boxHeight / 2, bevel, outerColor, innerColor, 1.0);

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

        // Remove if x position is higher than it should be
        if (xPosition > 9)
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
        LCS_Weapon selectedWeaponObject;

        // Used to calculate where to clamp the ghost
        int slotRowCount[10];

        Color color1;
        Color color2;

        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            LCS_Weapon currentWeapon = currentWeapons[i];

            int rowOffset = 0;
            slotRowCount[currentWeapon.slot]++;

            color1 = outerColor;
            color2 = innerColor;

            // This is the slot that has been clicked on
            if (slotSelected == (currentWeapon.slot, currentWeapon.row))
            {
                hasSlotSelected = true;
                selectedWeaponObject = currentWeapon;

                // Decrement because we no longer want to count this one
                slotRowCount[currentWeapon.slot]--;
            }
            else
            {
                // If a weapon is selected, and below where hovered over
                if (hasSlotSelected && currentWeapon.slot == mouseSlot.X && currentWeapon.row >= mouseSlot.Y)
                {
                    rowOffset++;
                }
                // Slide the weapon up if in the same slot as the slot selected
                // Must also be below the slot selected
                if (hasSlotSelected && currentWeapon.slot == slotSelected.X && currentWeapon.row > slotSelected.Y)
                {
                    rowOffset--;
                }
                // Slide only the one slot up
                if (
                    hasSlotSelected && currentWeapon.slot == slotSelected.X &&
                    currentWeapon.row == mouseSlot.Y && currentWeapon.slot == mouseSlot.X &&
                    currentWeapon.row > slotSelected.Y
                )
                {
                    rowOffset--;
                }

                // Highlight the slot selected with the mouse
                if (!hasSlotSelected && mouseSlot == (currentWeapon.slot, currentWeapon.row))
                {
                    color2 = highlightColor;
                }
                // Border if weapon is held by the player
                if (players[Consoleplayer].ReadyWeapon != null && players[Consoleplayer].ReadyWeapon.GetClassName() == currentWeapon.weapon.GetClassName())
                {
                    color1 = heldWeaponColor;
                }

                DrawWeaponBox(currentWeapon.slot, currentWeapon.row + rowOffset, currentWeapon, color1, color2);
            }
            //Console.printf("Drawing "..currentWeapon.weapon.GetClassName().." at %i, %i", currentWeapon.slot, currentWeapon.row);
        }

        if (hasSlotSelected) 
        {
            // Draw the weapon box as a ghost
            int ghostX = mouseSlot.X;
            int ghostY = mouseSlot.Y;

            bool validGhost = true;

            // Clamp if too far left
            if (ghostX < 0) 
            {
                ghostX = 0;
                validGhost = false;
            }
            // Clamp if too far right
            else if (ghostX > 9)
            {
                ghostX = 9;
                validGhost = false;
            }

            // Clamp if too high up
            if (ghostY < 0)
            {
                ghostY = 0;
                validGhost = false;
            }

            // Clamp where the ghost is drawn if too far down
            else if (ghostY > slotRowCount[ghostX])
            {
                ghostY = slotRowCount[ghostX];
            }

            // Color the ghost and cursor weapon
            color1 = outerColor;
            color2 = highlightColor;

            // Border if weapon is held
            if (players[Consoleplayer].ReadyWeapon.GetClassName() == selectedWeaponObject.weapon.GetClassName())
            {
                color1 = heldWeaponColor;
            }

            // Draw ghost
            if (validGhost) DrawWeaponBox(ghostX, ghostY, selectedWeaponObject, color1, color2, alphaValue);

            // Draw the weapon on the cursor if there is one
            DrawWeaponBoxOnCursor(selectedWeaponObject, color1, color2);
        }
    }

    private ui void DrawWeaponBox(int slot, int row, LCS_Weapon currentWeapon, Color color1, Color color2, float alphaValue = 1.0)
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
            color1,
            color2,
            alphaValue
        );

        Screen.DrawTexture(
            currentWeapon.weapon.FindState("Spawn", true).GetSpriteTexture(0, 0, (0, 0)),
            true,
            (boxWidth * slot) + (boxWidth / 2),
            (boxHeight * (row + 1) + (boxHeight / 6)),
            DTA_Alpha, alphaValue,
            DTA_ScaleX, scalingFactor * 1,
            DTA_ScaleY, scalingFactor * 1
        );

        Screen.DrawText(
            OriginalSmallFont, 
            fontColor, 
            slot * boxWidth + 2 * bevel, 
            (row + 1.3) * boxHeight, 
            currentWeapon.weapon.GetClassName(),
            DTA_Alpha, alphaValue,
            DTA_ScaleX, scalingFactor / 2,
            DTA_ScaleY, scalingFactor / 2,
            DTA_TextLen, 11
        );
    }

    private ui void DrawWeaponBoxOnCursor(LCS_Weapon currentWeapon, Color color1, Color color2, float alphaValue = 1.0)
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
            color1,
            color2,
            alphaValue
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
        // Check if valid
        if (slotNumber < 0 || slotNumber > 9) return;

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
            //Console.printf("Nothing happened...");
            return;
        }

        int oldCurrentSlot = (slotSelected.X == 9) ? 0 : slotSelected.X + 1;
        int newCurrentSlot = (slotNumber == 9) ? 0 : slotNumber + 1;

        //Console.printf(" oldslot: %i, newslot: %i", oldCurrentSlot, newCurrentSlot);

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
                //Console.printf("Old slot weapon: " .. oldSlotWeaponCVars[i]);

                oldSlotCurrentWeapons.push(oldSlotWeaponCVars[i]);
            }
        }

        Array<String> newSlotCurrentWeapons;
        for (int i = 0; i < newSlotWeaponCVars.Size(); i++)
        {
            if (currentWeaponStrings.Find(newSlotWeaponCVars[i]) != currentWeaponStrings.Size())
            {
                //Console.printf("New weapon:" .. newSlotWeaponCVars[i]);
                newSlotCurrentWeapons.push(newSlotWeaponCVars[i]);
            }
        }

        // Determine the indices
        // The old index is where the weapon is removed in the cvar,
        // the new one is where the weapon is added
        int newIndex;
        if (slotRow > newSlotCurrentWeapons.Size())
        {
            newIndex = newSlotCurrentWeapons.Size();
        }
        else
        {
            newIndex = slotRow;
        }

        // Adds the weapon to the new slot
        // Weapon being inserted into the list
        int newCVarStringIndex;
        bool isSameSlot = slotSelected.X == slotNumber;
        String CVarNoWeapon = newCVar.GetString();
        // Weapon added to the middle of the slot
        if (newIndex < newSlotCurrentWeapons.Size())
        {
            // Normal case
            if (!isSameSlot)
            {
                newCVarStringIndex = newCVar.GetString().IndexOf(newSlotCurrentWeapons[newIndex]);
                //Console.printf(" newCVar: "..newCVar.GetString().Left(newCVarStringIndex).." SPLIT "..newCVar.GetString().Mid(newCVarStringIndex));
                newCVar.SetString(newCVar.GetString().Left(newCVarStringIndex)..selectedWeaponString..","..newCVar.GetString().Mid(newCVarStringIndex));
            }
            // Need to exclude the old weapon here
            else
            {
                // If the new slot is before the current slot
                if (newIndex < slotSelected.Y)
                {
                    //Console.printf(" CVarNoWeapon1: "..CVarNoWeapon);
                    CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(selectedWeaponString), selectedWeaponString.Length() + 1);
                    //Console.printf(" CVarNoWeapon2: "..CVarNoWeapon);

                    //Console.printf("Before");
                    
                    newCVarStringIndex = CVarNoWeapon.IndexOf(newSlotCurrentWeapons[newIndex]);
                    //Console.printf(" newCVar: "..CVarNoWeapon.Left(newCVarStringIndex).." SPLIT "..CVarNoWeapon.Mid(newCVarStringIndex - 1));
                    newCVar.SetString(CVarNoWeapon.Left(newCVarStringIndex)..selectedWeaponString..","..CVarNoWeapon.Mid(newCVarStringIndex));
                }
                // If the new slot is after the current slot
                else
                {
                    // Need to decrement to avoid going out of bounds
                    if (newIndex < newSlotCurrentWeapons.Size() - 1)
                    {
                        //Console.printf("After");
                        // Delete the old weapon
                        CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(selectedWeaponString), selectedWeaponString.Length() + 1);

                        newCVarStringIndex = CVarNoWeapon.IndexOf(newSlotCurrentWeapons[newIndex + 1]);
                        //Console.printf(" newCVar: "..CVarNoWeapon.Left(newCVarStringIndex).." SPLIT "..CVarNoWeapon.Mid(newCVarStringIndex - 1));
                        newCVar.SetString(CVarNoWeapon.Left(newCVarStringIndex)..selectedWeaponString..","..CVarNoWeapon.Mid(newCVarStringIndex));
                    }
                    else
                    {
                        //newCVarStringIndex = CVarNoWeapon.IndexOf(newSlotCurrentWeapons[newIndex]);
                        //Console.printf("Very end");
                        // Delete the old weapon
                        CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(selectedWeaponString), selectedWeaponString.Length() + 1);
                        // Tack the weapon on to the end
                        newCVar.SetString(CVarNoWeapon..selectedWeaponString..",");
                    }
                }
            }
        }
        // Weapon added to the end of the list
        else
        {
            if (!isSameSlot)
            {
                newCVar.SetString(newCVar.GetString()..selectedWeaponString..",");
            }
            else
            {
                CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(selectedWeaponString), selectedWeaponString.Length() + 1);
                newCVar.SetString(CVarNoWeapon..selectedWeaponString..",");
            }
        }

        // Delete the old CVar
        // Need the index
        int oldIndex = oldCVar.getString().IndexOf(selectedWeaponString);

        // Delete the weapon at the index, only if a different slot
        if (!isSameSlot)
        {
            String newOldString = oldCVar.GetString();
            newOldString.Remove(oldIndex, selectedWeaponString.Length() + 1);
            oldCVar.SetString(newOldString);
        }

        // Refresh the screen
        UpdateCurrentWeaponsArray();
        SaveCurrentWeaponsToDisk();
        slotSelected = (-1, -1);
        hasSlotSelected = false;
        selectedWeaponString = "";
    }
}
extend class LSS_EventHandler
{
    ui Vector2 HudScale;

    ui Vector2 mouseSlot;

    ui Color outerColor;
    ui Color outerColorAlt;
    ui Color innerColor;
    ui Color innerColorAlt;
    ui Color highlightColor;
    ui Color heldWeaponColor;
    ui float ghostAlphaValue;
    ui float swapAlphaValue;

    ui int scalingFactor;
    ui int boxWidth;
    ui int boxHeight;
    ui int bevel;
    ui int slotNumberColor;
    ui int weaponNameColor;

    ui bool tryingToSwap;

    override void RenderOverlay(RenderEvent event)
    {
        if (!isEditing)
        {
            return;
        }

        int a, b, screenWidth, d; 
        [a, b, screenWidth, d] = Screen.GetViewWindow();
        scalingFactor = screenWidth / 480;

        boxWidth = 48 * scalingFactor;
        boxHeight = 40 * scalingFactor;
        bevel = 1 * scalingFactor;

        // Color stuff
        Color temp;
        temp = LSS_OuterColor;
        outerColor = color(temp.b, temp.g, temp.r);
        temp = LSS_InnerColor;
        innerColor = color(temp.b, temp.g, temp.r);
        temp = LSS_HighlightColor;
        highlightColor = color(temp.b, temp.g, temp.r);
        temp = LSS_HeldWeaponColor;
        heldWeaponColor = color(temp.b, temp.g, temp.r);
        ghostAlphaValue = LSS_GhostAlphaValue;
        swapAlphaValue = LSS_SwapAlphaValue;
        slotNumberColor = LSS_SlotNumberColor;
        weaponNameColor = LSS_WeaponNameColor;

        // Setting the alternating colors
        temp = (LSS_UsingAlternatingColors) ? LSS_OuterColorAlt : LSS_OuterColor;
        outerColorAlt = color(temp.b, temp.g, temp.r);
        temp = (LSS_UsingAlternatingColors) ? LSS_InnerColorAlt : LSS_InnerColor;
        innerColorAlt = color(temp.b, temp.g, temp.r);
        temp = LSS_HighlightColor;

        HudScale = StatusBar.GetHUDScale();
        //Screen.DrawThickLine(MousePosition.X, MousePosition.Y, 10, 10, HudScale.X, Color(255, 0, 255));
        //DrawBox((MousePosition.X, MousePosition.Y), boxWidth, boxHeight, bevel);

        // Draw the empty frame
        DrawFrame();

        // Calculate which slot should have been clicked on
        mouseSlot = CalculateSlotUnderMouse();

        // Insertion
        // Need to alternate
        if (mouseClicked) 
        {
            mouseClicked = false;
            mouseReleased = false;
            // Calculate if it was a valid click
            if (!hasSlotSelected)
            {
                tryingToSwap = true;
                CalculateMouseClick(mouseSlot.X, mouseSlot.Y);
            }
            // Replace the slot
            else
            {
                if (ReplaceSlot(mouseSlot.X, mouseSlot.Y))
                {
                    // Play successful sound
                    players[ConsolePlayer].mo.A_StartSound("LSS_SelectSound", 0, CHANF_UI == true, LSS_UIVolume, ATTN_NONE, cfrandom(0.5, 1.5));
                }
                else
                {
                    // Play invalid sound
                    players[ConsolePlayer].mo.A_StartSound("LSS_InvalidSound", 0, CHANF_UI == true, LSS_UIVolume, ATTN_NONE, 1);
                }
            }
        }
        
        // Swapping
        if (mouseReleased && hasSlotSelected)
        {
            mouseReleased = false;

            // Check if released on the same slot, is so, then do nothing
            if (slotSelected == mouseSlot)
            {
                tryingToSwap = false;
                //Console.printf("Not swapping.");

                // Playsound
                players[ConsolePlayer].mo.A_StartSound("LSS_SelectSound", 0, CHANF_UI == true, LSS_UIVolume, ATTN_NONE, cfrandom(0.5, 1.5));
            }
            else
            {
                tryingToSwap = false;
                //Console.printf("Swapping!");
                
                if (SwapSlot(slotSelected, mouseSlot))
                {
                    // Play successful sound
                    players[ConsolePlayer].mo.A_StartSound("LSS_SwapSound", 0, CHANF_UI == true, LSS_UIVolume, ATTN_NONE, cfrandom(0.8, 1.2));
                }
                else
                {
                    // Play invalid sound
                    players[ConsolePlayer].mo.A_StartSound("LSS_InvalidSound", 0, CHANF_UI == true, LSS_UIVolume, ATTN_NONE, 1);
                }
            }
        }

        DrawWeaponBoxes();
    }

    private ui void DrawBox(Vector2 origin, int width, int height, int bevel, Color color1, Color color2, float ghostAlphaValue)
    {
        // Outer square
        DrawSquare(origin, width, height, color1, ghostAlphaValue);

        // Inner one, needs an offset
        Vector2 innerOffset = (origin.X, origin.Y);

        DrawSquare(innerOffset, width - 4 * bevel, height - 4 * bevel, color2, ghostAlphaValue);
    }

    // Code copied from example at
    // https://zdoom.org/wiki/Classes:Shape2D
    private ui void DrawSquare(Vector2 origin, int width, int height, Color squareColor, float ghostAlphaValue)
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

        Screen.DrawShapeFill(squareColor, ghostAlphaValue, square);
    }

    private ui void DrawFrame()
    {
        Color color1;
        Color color2;

        for (int i = 0; i < 10; i++)
        {
            // Alternating colors
            color1 = (i % 2 == 0) ? outerColor : outerColorAlt;
            color2 = (i % 2 == 0) ? innerColor : innerColorAlt;

            // Draw each box for the numbers
            DrawBox((i * boxWidth + (boxWidth / 2), boxHeight / 4), boxWidth, boxHeight / 2, bevel, color1, color2, 1.0);

            // Digits are 1-9 and 0
            int digit = (i == 9) ? 0 : i + 1;

            Screen.DrawText(
                OriginalSmallFont, 
                slotNumberColor, 
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
        LSS_Weapon selectedWeaponObject;

        // Used to calculate where to clamp the ghost
        int slotRowCount[10];

        Color color1;
        Color color2;

        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            LSS_Weapon currentWeapon = currentWeapons[i];

            int rowOffset = 0;
            slotRowCount[currentWeapon.slot]++;

            // Alternating colors
            color1 = (currentWeapon.slot % 2 == 0) ? outerColor : outerColorAlt;
            color2 = (currentWeapon.slot % 2 == 0) ? innerColor : innerColorAlt;

            // This is the slot that has been clicked on
            if (slotSelected == (currentWeapon.slot, currentWeapon.row))
            {
                hasSlotSelected = true;
                selectedWeaponObject = currentWeapon;

                // Decrement because we no longer want to count this one
                slotRowCount[currentWeapon.slot]--;
            }
            // Trying to swap weapons
            else if (tryingToSwap && selectedWeaponString != "")
            {
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

                // Draw the other slots
                int alphaValue = (mouseSlot == (currentWeapon.slot, currentWeapon.row)) ? swapAlphaValue : 1;
                DrawWeaponBox(currentWeapon.slot, currentWeapon.row + rowOffset, currentWeapon, color1, color2, alphaValue);
            }
            // Trying to insert weapon
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
            // Alternating colors
            color1 = (ghostX % 2 == 0) ? outerColor : outerColorAlt;
            color2 = (ghostX % 2 == 0) ? innerColor : innerColorAlt;

            // Border if weapon is held
            if (players[Consoleplayer].ReadyWeapon.GetClassName() == selectedWeaponObject.weapon.GetClassName())
            {
                color1 = heldWeaponColor;
            }

            // Inserting weapon
            if (!tryingToSwap)
            {
                // Draw ghost
                if (validGhost) DrawWeaponBox(ghostX, ghostY, selectedWeaponObject, color1, color2, ghostAlphaValue);

                // Draw the weapon on the cursor if there is one
                DrawWeaponBoxOnCursor(selectedWeaponObject, color1, highlightColor);
            }
            // Dragging the cursor
            else
            {
                // Ghost on cursor
                if (validGhost) DrawWeaponBox(ghostX, ghostY, selectedWeaponObject, color1, color2, ghostAlphaValue);

                // Get the weapon swapping to
                LSS_Weapon weaponToSwap;
                for (int i = 0; i < currentWeapons.Size(); i++)
                {
                    if (currentWeapons[i].slot == ghostX && currentWeapons[i].row == ghostY)
                    {
                        weaponToSwap = currentWeapons[i];
                        break;
                    }
                }

                // Color the ghost and cursor weapon
                // Alternating colors
                color1 = (slotSelected.X % 2 == 0) ? outerColor : outerColorAlt;
                color2 = (slotSelected.X % 2 == 0) ? innerColor : innerColorAlt;

                // Border if weapon is held by the player
                if (
                    players[Consoleplayer].ReadyWeapon.GetClassName() == selectedWeaponObject.GetClassName())
                {
                    color1 = heldWeaponColor;
                }

                // Ghost where originally clicked
                if (weaponToSwap)
                {
                    if (validGhost)
                    {
                        // Valid swap
                        DrawWeaponBox(slotSelected.X, slotSelected.Y, weaponToSwap, color1, color2, ghostAlphaValue);
                    }
                    else
                    {
                        // Trying to swap into an invalid position
                        DrawWeaponBoxOnCursor(selectedWeaponObject, color1, color2, ghostAlphaValue);
                    }
                }
            }
        }
    }

    private ui void DrawWeaponBox(int slot, int row, LSS_Weapon currentWeapon, Color color1, Color color2, float ghostAlphaValue = 1.0)
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
            ghostAlphaValue
        );

        // Retrieving the sprite texture
        TextureID texture;
        // Flags from: https://zdoom.org/wiki/GetInventoryIcon
        int flags = 1 + 2 + 8 + 16;
        if (BaseStatusBar.GetInventoryIcon(currentWeapon.weapon, flags))
        {
            texture = BaseStatusBar.GetInventoryIcon(currentWeapon.weapon, flags);
        }
        else
        {
            texture = currentWeapon.weapon.FindState("Spawn", true).GetSpriteTexture(0, 0, (0, 0));
        }

        //Console.printf("%i", TexMan.CheckRealHeight(texture));

        // Getting the width and real height of the weapon sprites
        int textureWidth;
        int textureHeight;
        [textureWidth, textureHeight] = TexMan.GetSize(texture);
        textureHeight = TexMan.CheckRealHeight(texture);

        // Evil hardcoded values
        float textureByWidth = (textureWidth != 0) ? 44.0 / textureWidth : 1.0;
        float textureByHeight = (textureHeight != 0) ? 24.0 / textureHeight : 1.0;

        // Scale by the smaller value
        float textureScale = (textureByWidth < textureByHeight) ? textureByWidth : textureByHeight;

        //Console.printf("%f", textureScale);

        if (texture.IsValid())
        {
            Screen.DrawTexture(
                texture,
                true,
                (boxWidth * slot) + (boxWidth / 2),
                (boxHeight * (row + 1) - (boxHeight / 10)),
                DTA_Alpha, ghostAlphaValue,
                DTA_ScaleX, scalingFactor * textureScale,
                DTA_ScaleY, scalingFactor * textureScale,
                DTA_CenterOffset, true
            );
        }

        // Add return character after 12
        // 12 happens to be the size of the boxes
        String textToDraw = currentWeapon.weapon.GetTag();
        int returnIndex = textToDraw.RightIndexOf(" ", 12);
        if (returnIndex == -1) returnIndex == 12;

        String lineOne = textToDraw.Left(returnIndex);
        String lineTwo = textToDraw.Mid(returnIndex + 1);
        
        if (lineOne != lineTwo) textToDraw = lineOne.."\n"..lineTwo;
        else textToDraw = lineOne;

        Screen.DrawText(
            OriginalSmallFont, 
            weaponNameColor, 
            slot * boxWidth + 2 * bevel, 
            (row + 1.235) * boxHeight, 
            textToDraw,
            DTA_Alpha, ghostAlphaValue,
            DTA_ScaleX, scalingFactor / 2,
            DTA_ScaleY, scalingFactor / 2,
            DTA_ClipRight, (slot + 1) * boxWidth - 2 * bevel
        );
    }

    private ui void DrawWeaponBoxOnCursor(LSS_Weapon currentWeapon, Color color1, Color color2, float ghostAlphaValue = 1.0)
    {
        // Offset from cursor
        Vector2 offset = (boxWidth / 2, boxHeight / 2) * LSS_CursorOffset;

        // Draw the box first,
        // then draw the weapon sprite,
        // finally, draw the text over the sprite
        DrawBox(
            (MousePosition.X + offset.X,
            MousePosition.Y + offset.Y),
            boxWidth,
            boxHeight,
            bevel,
            color1,
            color2,
            ghostAlphaValue
        );

        // Retrieving the sprite texture
        TextureID texture;
        // Flags from: https://zdoom.org/wiki/GetInventoryIcon
        int flags = 1 + 2 + 8 + 16;
        if (BaseStatusBar.GetInventoryIcon(currentWeapon.weapon, flags))
        {
            texture = BaseStatusBar.GetInventoryIcon(currentWeapon.weapon, flags);
        }
        else
        {
            texture = currentWeapon.weapon.FindState("Spawn", true).GetSpriteTexture(0, 0, (0, 0));
        }

        //Console.printf("%i", TexMan.CheckRealHeight(texture));

        // Getting the width and real height of the weapon sprites
        int textureWidth;
        int textureHeight;
        [textureWidth, textureHeight] = TexMan.GetSize(texture);
        textureHeight = TexMan.CheckRealHeight(texture);

        // Evil hardcoded values
        float textureByWidth = (textureWidth != 0) ? 44.0 / textureWidth : 1.0;
        float textureByHeight = (textureHeight != 0) ? 24.0 / textureHeight : 1.0;

        // Scale by the smaller value
        float textureScale = (textureByWidth < textureByHeight) ? textureByWidth : textureByHeight;

        //Console.printf("%f", textureScale);

        if (texture.IsValid())
        {
            Screen.DrawTexture(
                texture,
                true,
                MousePosition.X + offset.X,
                MousePosition.Y - (boxHeight / 10) + offset.Y,
                DTA_Alpha, ghostAlphaValue,
                DTA_ScaleX, scalingFactor * textureScale,
                DTA_ScaleY, scalingFactor * textureScale,
                DTA_CenterOffset, true
            );
        }

        /*
        Screen.DrawTexture(
            currentWeapon.weapon.FindState("Spawn", true).GetSpriteTexture(0, 0, (0, 0)),
            true,
            MousePosition.X + offset.X,
            MousePosition.Y + (boxHeight / 6) + offset.Y,
            DTA_Alpha, ghostAlphaValue,
            DTA_ScaleX, scalingFactor * 1,
            DTA_ScaleY, scalingFactor * 1
        );
        */

        // Add return character after 12
        // 12 happens to be the size of the boxes
        String textToDraw = currentWeapon.weapon.GetTag();
        int returnIndex = textToDraw.RightIndexOf(" ", 12);
        if (returnIndex == -1) returnIndex == 12;

        String lineOne = textToDraw.Left(returnIndex);
        String lineTwo = textToDraw.Mid(returnIndex + 1);
        
        if (lineOne != lineTwo) textToDraw = lineOne.."\n"..lineTwo;
        else textToDraw = lineOne;

        // Needed to cast as an int
        int clipRight = (mousePosition.X) + (boxWidth * 0.5) - 2 * bevel + offset.X;

        Screen.DrawText(
            OriginalSmallFont, 
            weaponNameColor, 
            MousePosition.X - (boxWidth / 2) + (2 * bevel) + offset.X, 
            MousePosition.Y + 0.235 * boxHeight + offset.Y, 
            textToDraw,
            DTA_Alpha, ghostAlphaValue,
            DTA_ScaleX, scalingFactor / 2,
            DTA_ScaleY, scalingFactor / 2,
            DTA_ClipRight, clipRight
        );

        /*
        Screen.DrawText(
            OriginalSmallFont, 
            weaponNameColor, 
            MousePosition.X - (boxWidth / 2) + (2 * bevel) + offset.X, 
            MousePosition.Y + (.3) * boxHeight + offset.Y, 
            currentWeapon.weapon.GetClassName(),
            DTA_ScaleX, scalingFactor / 2,
            DTA_ScaleY, scalingFactor / 2,
            DTA_TextLen, 11
        );
        */
    }

    private ui void CalculateMouseClick(int slotNumber, int slotRow)
    {
        // Check if valid
        if (slotNumber < 0 || slotNumber > 9) return;

        int oldCurrentSlot = (slotNumber == 9) ? 0 : slotNumber + 1;

        // This is the list of weapons for the slots
        CVar oldCVar = CVar.GetCvar("LSS_Slot"..oldCurrentSlot, players[ConsolePlayer]);

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
    *   Returns true if successful, false if not
    */
    private ui bool ReplaceSlot(int slotNumber, int slotRow)
    {
        // Clicked out of bounds, nothing happens
        if (mouseSlot == (-1, -1))
        {
            return false;
        }

        // Clicked the same slot, set it down and do nothing else
        if ((slotNumber, slotRow) == slotSelected)
        {
            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";
            //Console.printf("Nothing happened...");
            return true;
        }

        int oldCurrentSlot = (slotSelected.X == 9) ? 0 : slotSelected.X + 1;
        int newCurrentSlot = (slotNumber == 9) ? 0 : slotNumber + 1;

        //Console.printf(" oldslot: %i, newslot: %i", oldCurrentSlot, newCurrentSlot);

        // This is the list of weapons for the slots
        CVar oldCVar = CVar.GetCvar("LSS_Slot"..oldCurrentSlot, players[ConsolePlayer]);
        CVar newCVar = CVar.GetCvar("LSS_Slot"..newcurrentSlot, players[ConsolePlayer]);

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
                newCVarStringIndex = newCVar.GetString().IndexOf(","..newSlotCurrentWeapons[newIndex]..",") + 1;
                //Console.printf(" newCVar:"..newCVar.GetString().Left(newCVarStringIndex).."SPLIT"..newCVar.GetString().Mid(newCVarStringIndex));
                newCVar.SetString(newCVar.GetString().Left(newCVarStringIndex)..selectedWeaponString..","..newCVar.GetString().Mid(newCVarStringIndex));
            }
            // Need to exclude the old weapon here
            else
            {
                // If the new slot is before the current slot
                if (newIndex < slotSelected.Y)
                {
                    //Console.printf(" CVarNoWeapon1: "..CVarNoWeapon);
                    CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(","..selectedWeaponString..",") + 1, selectedWeaponString.Length() + 1);
                    //Console.printf(" CVarNoWeapon2: "..CVarNoWeapon);

                    //Console.printf("Before");
                    
                    newCVarStringIndex = CVarNoWeapon.IndexOf(","..newSlotCurrentWeapons[newIndex]..",") + 1;
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
                        //Console.printf(" unmodified newCVar:"..CVarNoWeapon);
                        CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(","..selectedWeaponString..",") + 1, selectedWeaponString.Length() + 1);
                        //Console.printf(" deleted weapon newCVar:"..CVarNoWeapon);

                        newCVarStringIndex = CVarNoWeapon.IndexOf(","..newSlotCurrentWeapons[newIndex + 1]..",") + 1;
                        //Console.printf(" newCVar:"..CVarNoWeapon.Left(newCVarStringIndex).."SPLIT"..CVarNoWeapon.Mid(newCVarStringIndex - 1));
                        newCVar.SetString(CVarNoWeapon.Left(newCVarStringIndex)..selectedWeaponString..","..CVarNoWeapon.Mid(newCVarStringIndex));
                    }
                    else
                    {
                        //newCVarStringIndex = CVarNoWeapon.IndexOf(newSlotCurrentWeapons[newIndex]);
                        //Console.printf("Very end");
                        // Delete the old weapon
                        CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(","..selectedWeaponString..",") + 1, selectedWeaponString.Length() + 1);
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
                CVarNoWeapon.Remove(CVarNoWeapon.IndexOf(","..selectedWeaponString..",") + 1, selectedWeaponString.Length() + 1);
                newCVar.SetString(CVarNoWeapon..selectedWeaponString..",");
            }
        }

        // Delete the old CVar
        // Need the index
        int oldIndex = oldCVar.getString().IndexOf(","..selectedWeaponString..",") + 1;

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
        return true;
    }

    /***
    *   Tried to swap start and destination.
    *   Returns true if successful, false if not
    */
    private ui bool SwapSlot(Vector2 start, Vector2 destination)
    {
        // Invalid destination
        if (destination.X < 0 || destination.X > 10 || destination.Y < 0)
        {
            // Refresh the screen
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();
            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";
            return false;
        }

        // Check how many rows
        int weaponsInSlot = 0;
        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            if (currentWeapons[i].slot == destination.X)
            {
                weaponsInSlot++;
            }
        }

        // Move the first weapon
        ReplaceSlot(destination.X, destination.Y);

        if (weaponsInSlot == 0) return true;

        // Clamp the row if too far
        int newDestinationRow;
        if (destination.Y > weaponsInSlot + 1)
        {
            newDestinationRow = weaponsInSlot + 1;
        }
        else
        {
            newDestinationRow = destination.Y;
        }

        int offset;
        if (start.X != destination.X || start.Y > destination.Y) offset = 1;
        else offset = -1;

        // Set up the second weapon
        slotSelected = (destination.X, destination.Y + offset);

        for (int i = 0; i < currentWeapons.Size(); i++)
        {
            if (currentWeapons[i].slot == destination.X && currentWeapons[i].row == newDestinationRow + offset)
            {
                selectedWeaponString = currentWeapons[i].weapon.GetClassName();
                break;
            }
        }

        // If empty string, that slot is empty, so do not swap anything
        //Console.printf(" weapon to swap: "..selectedWeaponString);
        if (selectedWeaponString == "")
        {
            // Refresh the screen
            UpdateCurrentWeaponsArray();
            SaveCurrentWeaponsToDisk();
            slotSelected = (-1, -1);
            hasSlotSelected = false;
            selectedWeaponString = "";
            return true;
        }

        // Move the second weapon
        ReplaceSlot(start.X, start.Y);
        return true;
    }
}
extend class LCS_EventHandler
{
    ui Vector2 HudScale;
    ui Color outerColor;
    ui Color innerColor;
    ui Color highlightColor;

    ui Vector2 mouseSlot;

    ui float scalingFactor;
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

        DrawFrame();
        mouseSlot = CalculateSlotUnderMouse();
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
        if (MousePosition.Y <= boxHeight / 2) yPosition = -1;

        //Console.printf("%i, %i", xPosition, yPosition);

        return (xPosition, yPosition);
    }

    private ui void DrawWeaponBoxes()
    {
        for (int i = 0; i < 10; i++)
        {
            int row = 0;
            int currentSlot = (i == 9) ? 0 : i + 1;
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
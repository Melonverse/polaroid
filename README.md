# About

![Screenshot](https://toolblocks.gg/cdn/FbGjBT8zFmqxKuB8riag)

Polaroid Instant is the developer tool for Roblox that allows you to bring the classic Polaroid Film experience
to your game!

With Polaroid Instant, you can add a Polaroid camera feature to your game, giving users the ability to take selfies and
place them inside the iconic white Polaroid frame. Users can adjust lighting and pick poses for their character, making
it a fun and interactive way to capture memories and share them with friends.

# Installation

## From ToolBlocks

The Polaroid tool is available for download on ToolBlocks, so you can download and insert it directly into your game:

https://toolblocks.gg/a/polaroid.W0XAdtA4JedY6PAJ7ckQ

Download the tool and place it in your game by dragging and dropping the file into Roblox studio. Once inserted, place
the module under ReplicatedStorage.

## From Roblox

The tool is also available on the Roblox library.
https://create.roblox.com/marketplace/asset/14190431961/Polaroid-Capture-Tool

# Usage

This tutorial will assume you placed the module in `ReplicatedStorage`.

## Getting the Module

```lua title="example.lua"
local Polaroid = require(
    game:GetService("ReplicatedStorage"):WaitForChild("Polaroid")
)
```

## Initializing and activating the camera

In this example, we'll use an existing UI button to toggle the camera's visibility.

```lua title="example.lua"
local Polaroid = require(
    game:GetService("ReplicatedStorage"):WaitForChild("Polaroid")
)

local Player = game:GetService("Players").LocalPlayer;
if not Player:HasAppearanceLoaded() then
    Player.CharacterAppearanceLoaded:Wait();
end

local Camera = Polaroid()
local isVisible = false

local ShowCameraButton =  -- insert code to get the GUI button button here

ShowCameraButton.OnClick:Connect(function()
    isVisible = not isVisible

    if isVisible then
        Camera.Show()
    else
        Camera.Hide()
    end
end)
```
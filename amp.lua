-- This file contains part of the CC: Tweaked development repository.

-- SPDX-FileCopyrightText: 2021 The CC: Tweaked Developers
--
-- SPDX-License-Identifier: MPL-2.0

local function get_speakers(name)
    if name then
        local speaker = peripheral.wrap(name)
        if speaker == nil then
            error(("Speaker %q does not exist"):format(name), 0)
            return
        elseif not peripheral.hasType(name, "speaker") then
            error(("%q is not a speaker"):format(name), 0)
        end

        return { speaker }
    else
        local speakers = { peripheral.find("speaker") }
        if #speakers == 0 then
            error("No speakers attached", 0)
        end
        return speakers
    end
end

-- -----------------------------
-- DSP functions
local function clip(sample, strength)
    return math.max(-128, math.min(127, sample*strength))
end

local function saturate(sample, strength)
    local x = ((1/(1+2.7182818284590452354^((-1/(32-strength))*sample)))-0.5)*2*127
    return clip(x, 1)
end
--- 

local dfpwm = require("cc.audio.dfpwm")

-- command usage:
-- amp <play/stop> <link> [volume] [mode(c/s)]
local cmd, link, volume, mode = ...

if cmd == "play" then
    -- dfpwm file handling
    local handle, err
    if http and link:match("^https?://") then
        print("Downloading...")
        handle, err = http.get(link)
    else
        handle, err = fs.open(shell.resolve(link), "r")
    end
    if not handle then
        printError("Could not play audio:")
        error(err, 0)
    end

    -- player handling
    local final_volume = tonumber(volume) or 1
    local speakers = get_speakers()
    local decoder = dfpwm.make_decoder()
    local size = 8 * 1024
    local dspFunction = mode == "s" and saturate or clip 
    while true do
        local chunk = handle.read(size)
        if not chunk then break end

        local buffer = decoder(chunk)

        for i = 1, #buffer, 1 do
            -- dsp function
            buffer[i] = dspFunction(buffer[i], final_volume)
        end

        while not speakers[1].playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

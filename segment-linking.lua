--[[
    A script to implement support for matroska next/prev segment linking.
    Available at: https://github.com/CogentRedTester/mpv-segment-linking

    This is a different feature to ordered chapters, which mpv already supports natively.
    This script requires mkvinfo to be available in the system path.
]]--

local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

local FLAG_CHAPTER_FIX
local LATEST_LIST

local ORDERED_CHAPTERS_ENABLED
local REFERENCES_ENABLED
local MERGE_THRESHOLD

--file extensions that support segment linking
local file_extensions = {
    mkv = true,
    mka = true
}

--returns the uid of the given file, along with the previous and next uids if they exist
local function get_uids(file)
    local cmd = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {"mkvinfo", file}
    })

    if cmd.status ~= 0 then
        msg.error("could not read file", file)
        return
    end

    local output = cmd.stdout
    return  output:match("Segment UID: ([^\n\r]+)"),
            output:match("Previous segment UID: ([^\n\r]+)"),
            output:match("Next segment UID: ([^\n\r]+)")
end

--creates a table to allow easy uid resolution for chained segments
local function create_uid_database(files, directory)
    local files_segments = {}
    for _, file in ipairs(files) do
        local file_ext = file:match("%.(%w+)$")

        if file_extensions[file_ext] then
            file = utils.join_path(directory,file)
            local uid, prev, next = get_uids(file)
            if uid ~= nil then
                files_segments[uid] = {
                    prev = prev,
                    next = next,
                    file = file
                }
            end
        end
    end
    return files_segments
end

--builds a timeline of linked segments for the current file
local function main()
    --we will respect these options just as ordered chapters do
    if not (ORDERED_CHAPTERS_ENABLED and REFERENCES_ENABLED) then return end

    local path = mp.get_property("stream-open-filename", "")
    local file_ext = path:match("%.(%w+)$")

    --if not a file that can contain segments, or if the file isn't available locally, then return
    if not file_extensions[file_ext] then return end
    if not utils.file_info(path) then return end

    --read the uid info for the current file
    local uid, prev, next = get_uids(path)
    if not uid then return end
    if not prev and not next then return end

    ------------------------------------------------------------------
    ---------- Most files will stop before here ----------------------
    ------------------------------------------------------------------

    msg.info("File uses linked segments, will build edit timeline.")
    local list = {path}

    local directory
    local files
    local ordered_chapters_files = mp.get_property("ordered-chapters-files", "")

    --grabs either the contents of the current directory, or the contents of the `ordered-chapters-files` option
    if ordered_chapters_files == "" then
        --grabs the directory portion of the original path
        directory = path:match("^(.+[/\\])[^/\\]+[/\\]?$")
        files = utils.readdir(directory, "files")

        msg.info("Will scan other files in the same directory to find referenced sources.")

    else
        msg.info("Loading references from '"..ordered_chapters_files.."'")

        local pl = io.open(ordered_chapters_files, "r")
        if not pl then
            msg.error("Cannot open file '"..ordered_chapters_files.."': No such file or directory")
            return
        end

        files = {}
        for line in pl:lines() do
            --remove the newline character at the end of the playlist
            table.insert(files, line:sub(1, -2))
        end
        directory = ordered_chapters_files:match("^(.+[/\\])[^/\\]+[/\\]?$")
    end

    local database = create_uid_database(files, directory)

    --adds the next and previous segment ids until re3aching the end of the uid chain
    while (prev and database[prev]) do
        msg.info("Match for previous segment:", database[prev].file)
        table.insert(list, 1, database[prev].file)
        prev = database[prev].prev
    end

    while (next and database[next]) do
        msg.info("Match for next segment:", database[next].file)
        table.insert(list, database[next].file)
        next = database[next].next
    end

    --we'll use the mpv edl specification to merge the files into one seamless timeline
    local edl_path = "edl://"
    for _, segment in ipairs(list) do
        edl_path = edl_path..segment..",title=__segment_linking_title__;"
    end
    mp.set_property("stream-open-filename", edl_path)

    --flag fixes for the chapters
    FLAG_CHAPTER_FIX = true
    LATEST_LIST = list
end

--remove chapters added by the edl specification and within the merge threshold
--segment linking does not have chapter generation as part of the specification and vlc does not do this, so we'll remove them all
--if the new chapters created by the edl stream are exactly equal to an existing chapter then
--it can make it impossible to seek backwards past the chapter unless we remove something
--other larger chapter mismatches are the responsibility of the encoder
local function fix_chapters()
    if not FLAG_CHAPTER_FIX or not LATEST_LIST then return end

    local chapters = mp.get_property_native("chapter-list", {})

    for i=#chapters, 1, -1 do
        if chapters[i].title == "__segment_linking_title__" then
            table.remove(chapters, i)
        end
    end

    for i = #chapters, 2, -1 do
        if math.abs(chapters[i].time - chapters[i-1].time) < MERGE_THRESHOLD then
            table.remove(chapters, i)
        end
    end

    mp.set_property_native("chapter-list", chapters)

    FLAG_CHAPTER_FIX = false
end

mp.add_hook("on_load", 10, main)
mp.add_hook("on_preloaded", 10, fix_chapters)
mp.observe_property("access-references", "bool", function(_, val) REFERENCES_ENABLED = val end)
mp.observe_property("ordered-chapters", "bool", function(_, val) ORDERED_CHAPTERS_ENABLED = val end)
mp.observe_property("chapter-merge-threshold", "number", function(_, val) MERGE_THRESHOLD = val/1000 end)
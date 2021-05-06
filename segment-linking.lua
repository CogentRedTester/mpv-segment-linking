local mp = require "mp"
local msg = require "mp.msg"
local utils = require "mp.utils"

local ORDERED_CHAPTERS_ENABLED
local REFERENCES_ENABLED
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

local function create_uid_database(files, directory)
    local files_segments = {}
    for _, file in ipairs(files) do
        local file_ext = file:match("%.(%w+)$")

        if file_extensions[file_ext] then
            file = directory..file
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

local function main()
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

    msg.info("File uses linked segments, will build edit timeline.")

    local directory
    local list = {path}
    local files
    local ordered_chapters_files = mp.get_property("ordered-chapters-files", "")

    if ordered_chapters_files == "" then
        --grabs the directory portion of the original path
        directory = path:match("^(.+[/\\])[^/\\]+[/\\]?$")

        local full_path = utils.join_path(mp.get_property("working-directory", ""), path)
        files = utils.readdir(utils.split_path(full_path), "files")

        msg.info("Will scan other files in the same directory to find referenced sources.")
    else
        directory = ordered_chapters_files:match("^(.+[/\\])[^/\\]+[/\\]?$")

        local pl = io.open(ordered_chapters_files, "r")
        files = {}
        for line in pl:lines() do
            --remove the newline character at the end of the playlist
            table.insert(files, line:sub(1, -2))
        end

        msg.info("Loading references from '"..ordered_chapters_files.."'")
    end

    local database = create_uid_database(files, directory)

    --adds the next and previous segment ids until re3aching the end of the uid chain
    while (prev and database[prev]) do
        table.insert(list, 1, database[prev].file)
        msg.info("Match for previous segment:", database[prev].file)

        prev = database[prev].prev
    end

    while (next and database[next]) do
        table.insert(list, database[next].file)
        msg.info("Match for next segment:", database[next].file)

        next = database[next].next
    end

    local edl_path = "edl://" .. table.concat(list, ";")
    mp.set_property("stream-open-filename", edl_path)
end

mp.add_hook("on_load", 20, main)
mp.observe_property("access-references", "bool", function(_, val) REFERENCES_ENABLED = val end)
mp.observe_property("ordered-chapters", "bool", function(_, val) ORDERED_CHAPTERS_ENABLED = val end)
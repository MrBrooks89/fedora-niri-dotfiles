--!nonstrict

local isOpen = false
local query = ""
local currentCategory = nil
local applications = {}
local applicationsLoading = false
local applicationsLoaded = false
local inputGeneration = 0
local selectedIndex = 1
local scrollGeneration = 0
local scrollToBottomRevision = 0
local scrollAtBottom = false
local TOP_VIEW_LAST_INDEX = 5
local KEYBOARD_CONTEXT_ROWS = 5
local keyboardContextVisible = false

local categories = {
    { id = "applications", title = "Applications", subtitle = "Installed desktop applications", glyph = "apps" },
    { id = "system", title = "System", subtitle = "Controls, connectivity and status", glyph = "settings" },
    { id = "capture", title = "Capture", subtitle = "Screenshots, recording, color and OCR", glyph = "camera" },
    { id = "appearance", title = "Appearance", subtitle = "Themes, wallpapers and shell settings", glyph = "palette" },
    { id = "tools", title = "Tools", subtitle = "Terminal, files, configuration and updates", glyph = "tools" },
    { id = "power", title = "Power", subtitle = "Lock, suspend and session controls", glyph = "power" },
}

local nestedCategories = {
    { id = "sharing", parent = "tools", title = "Sharing", subtitle = "Send files and messages to nearby devices", glyph = "share" },
}

local actions = {
    { id = "control-center", category = "system", title = "Control Center", glyph = "adjustments", dispatch = "System › Control Center" },
    { id = "audio", category = "system", title = "Audio", glyph = "volume", dispatch = "System › Audio" },
    { id = "network", category = "system", title = "Network", glyph = "wifi", dispatch = "System › Network" },
    { id = "bluetooth", category = "system", title = "Bluetooth", glyph = "bluetooth", dispatch = "System › Bluetooth" },
    { id = "activity", category = "system", title = "System Activity", glyph = "activity", dispatch = "System › System Activity" },
    { id = "clipboard", category = "system", title = "Clipboard History", glyph = "clipboard", dispatch = "System › Clipboard History" },
    { id = "caffeine", category = "system", title = "Toggle Caffeine", glyph = "coffee", dispatch = "System › Toggle Caffeine" },
    { id = "dnd", category = "system", title = "Toggle Do Not Disturb", glyph = "bell-off", dispatch = "System › Toggle Do Not Disturb" },

    { id = "region", category = "capture", title = "Region Screenshot", glyph = "crop", dispatch = "Capture › Region Screenshot" },
    { id = "window", category = "capture", title = "Focused Window Screenshot", glyph = "app-window", dispatch = "Capture › Focused Window Screenshot" },
    { id = "output", category = "capture", title = "Focused Output Screenshot", glyph = "device-desktop", dispatch = "Capture › Focused Output Screenshot" },
    { id = "all-outputs", category = "capture", title = "All Outputs Screenshot", glyph = "devices", dispatch = "Capture › All Outputs Screenshot" },
    { id = "annotate", category = "capture", title = "Annotate Region", glyph = "pencil", dispatch = "Capture › Annotate Region" },
    { id = "record", category = "capture", title = "Screen Recorder", glyph = "video", dispatch = "Capture › Screen Recorder" },
    { id = "color", category = "capture", title = "Color Picker", glyph = "color-picker", dispatch = "Capture › Color Picker" },
    { id = "ocr", category = "capture", title = "OCR Region to Clipboard", glyph = "text-scan-2", dispatch = "Capture › OCR Region to Clipboard" },
    { id = "screenshots", category = "capture", title = "Open Screenshots Folder", glyph = "folder", dispatch = "Capture › Open Screenshots Folder" },

    { id = "themes", category = "appearance", title = "Themes", glyph = "color-swatch", dispatch = "Appearance › Themes" },
    { id = "wallpapers", category = "appearance", title = "Wallpapers", glyph = "photo", dispatch = "Appearance › Wallpapers" },
    { id = "mode", category = "appearance", title = "Toggle Light/Dark Mode", glyph = "sun-moon", dispatch = "Appearance › Toggle Light/Dark Mode" },
    { id = "settings", category = "appearance", title = "Noctalia Settings", glyph = "settings", dispatch = "Appearance › Noctalia Settings" },

    { id = "terminal", category = "tools", title = "Terminal", glyph = "terminal-2", dispatch = "Tools › Terminal" },
    { id = "btop", category = "tools", title = "System Monitor (btop)", glyph = "chart-histogram", dispatch = "Tools › System Monitor (btop)" },
    { id = "files", category = "tools", title = "File Manager", glyph = "folder", dispatch = "Tools › File Manager" },
    { id = "niri-config", category = "tools", title = "Edit Niri Config", glyph = "file-settings", dispatch = "Tools › Edit Niri Config" },
    { id = "noctalia-config", category = "tools", title = "Edit Noctalia Config", glyph = "file-settings", dispatch = "Tools › Edit Noctalia Config" },
    { id = "updates", category = "tools", title = "Fedora Updates", glyph = "refresh", dispatch = "Tools › Fedora Updates" },
    { id = "sharing", category = "tools", title = "Sharing", subtitle = "Send files and messages to nearby devices", glyph = "share", childCategory = "sharing" },
    { id = "reminder-5m", category = "tools", title = "Reminder in 5 Minutes", glyph = "clock", dispatch = "Tools › Reminder in 5 Minutes" },
    { id = "reminder-15m", category = "tools", title = "Reminder in 15 Minutes", glyph = "clock", dispatch = "Tools › Reminder in 15 Minutes" },
    { id = "reminder-30m", category = "tools", title = "Reminder in 30 Minutes", glyph = "clock", dispatch = "Tools › Reminder in 30 Minutes" },
    { id = "reminders-list", category = "tools", title = "List Reminders", glyph = "list", dispatch = "Tools › List Reminders" },
    { id = "reminders-clear", category = "tools", title = "Clear Reminders", glyph = "trash", dispatch = "Tools › Clear Reminders" },

    { id = "localsend", category = "sharing", title = "Open LocalSend", glyph = "share", dispatch = "Sharing › Open LocalSend" },
    { id = "outlook-web-app", category = "sharing", title = "Open Outlook Web App", glyph = "mail", dispatch = "Sharing › Open Outlook Web App" },

    { id = "lock", category = "power", title = "Lock", glyph = "lock", dispatch = "Power › Lock" },
    { id = "suspend", category = "power", title = "Suspend", glyph = "moon", dispatch = "Power › Suspend" },
    { id = "logout", category = "power", title = "Log Out", glyph = "logout", dispatch = "Power › Log Out" },
    { id = "restart", category = "power", title = "Restart", glyph = "reload", dispatch = "Power › Restart" },
    { id = "shutdown", category = "power", title = "Shut Down", glyph = "power", dispatch = "Power › Shut Down" },
}

local function splitTabs(line)
    local fields = {}
    local start = 1
    while true do
        local pos = string.find(line, "\t", start, true)
        if pos == nil then
            fields[#fields + 1] = string.sub(line, start)
            break
        end
        fields[#fields + 1] = string.sub(line, start, pos - 1)
        start = pos + 1
    end
    return fields
end

local function categoryById(id)
    for _, category in ipairs(categories) do
        if category.id == id then return category end
    end
    for _, category in ipairs(nestedCategories) do
        if category.id == id then return category end
    end
    return nil
end

local function score(pattern, text)
    if pattern == "" then return 0 end
    return noctalia.fuzzyScore(string.lower(pattern), string.lower(text or ""))
end

local function matchingItems()
    local results = {}
    local trimmed = noctalia.string.trim(query)

    if trimmed == "" then
        if currentCategory == nil then return categories end
        if currentCategory == "applications" then
            for _, application in ipairs(applications) do results[#results + 1] = application end
            return results
        end
        for _, action in ipairs(actions) do
            if action.category == currentCategory then results[#results + 1] = action end
        end
        return results
    end

    for _, action in ipairs(actions) do
        local category = categoryById(action.category)
        local haystack = action.title .. " " .. (category and category.title or "")
        local value = score(trimmed, haystack)
        if value ~= nil then
            results[#results + 1] = { kind = "action", value = action, score = value }
        end
    end

    for _, application in ipairs(applications) do
        local value = score(trimmed, application.title .. " " .. application.subtitle .. " " .. application.id)
        if value ~= nil then
            results[#results + 1] = { kind = "application", value = application, score = value }
        end
    end

    table.sort(results, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.value.title < b.value.title
    end)

    local flattened = {}
    for _, result in ipairs(results) do
        local item = result.value
        item.searchKind = result.kind
        flattened[#flattened + 1] = item
    end
    return flattened
end

local render

local function resetScrollToTop()
    scrollAtBottom = false
    keyboardContextVisible = false
    scrollGeneration += 1
end

local function followSelection(itemCount)
    if itemCount == 0 or selectedIndex <= TOP_VIEW_LAST_INDEX then
        if scrollAtBottom then resetScrollToTop() end
    else
        keyboardContextVisible = selectedIndex <= itemCount - TOP_VIEW_LAST_INDEX
        scrollAtBottom = true
        scrollToBottomRevision += 1
    end
end

local function closeAndRun(argv)
    panel.close()
    noctalia.runAsync(argv)
end

local function openCategory(category)
    currentCategory = category.id
    query = ""
    selectedIndex = 1
    resetScrollToTop()
    inputGeneration += 1
    render()
end

local function activateAction(action)
    closeAndRun({ noctalia.pluginDir() .. "/dispatch-action.sh", action.dispatch })
end

local function activateApplication(application)
    closeAndRun({ "gio", "launch", application.path })
end

local function activateItem(item)
    if item == nil then return end
    if item.path ~= nil then activateApplication(item)
    elseif item.dispatch ~= nil then activateAction(item)
    elseif item.childCategory ~= nil then openCategory(categoryById(item.childCategory))
    elseif item.id ~= nil then openCategory(item) end
end

local function resultRow(item, selected, keyPrefix)
    local isApplication = item.path ~= nil
    local subtitle = item.subtitle or ""
    if query ~= "" then
        if isApplication then
            subtitle = subtitle ~= "" and ("Application · " .. subtitle) or "Application"
        else
            local category = categoryById(item.category)
            subtitle = category and category.title or "Command"
        end
    end

    -- Keep interactive renders below Noctalia's plugin callback budget. Theme
    -- icon discovery is synchronous and can run once per application on the
    -- first broad search or Applications view, so use the native glyph here.
    local iconNode = ui.glyph({ name = item.glyph or "app-window", size = 22, color = "primary" })

    return ui.row({
        key = (keyPrefix or "") .. (isApplication and "app-" or "action-") .. item.id,
        height = 54,
        paddingH = 12,
        gap = 12,
        align = "center",
        fill = selected and "primary/0.18" or "surface_variant/0.38",
        borderWidth = selected and 1 or 0,
        radius = 11,
        onClick = function()
            if isApplication then activateApplication(item) else activateAction(item) end
        end,
    }, {
        ui.row({ width = 36, height = 36, align = "center", justify = "center", fill = "primary/0.10", radius = 9 }, { iconNode }),
        ui.column({ gap = 1, flexGrow = 1 }, {
            ui.label({ text = item.title, fontSize = 14, fontWeight = "semibold", color = "on_surface", maxLines = 1 }),
            ui.label({ text = subtitle, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
        }),
        ui.glyph({ name = "arrow-right", size = 15, color = "on_surface_variant" }),
    })
end

local function categoryRow(category, selected)
    return ui.row({
        key = "category-" .. category.id,
        height = 62,
        paddingH = 13,
        gap = 13,
        align = "center",
        fill = selected and "primary/0.18" or "surface_variant/0.38",
        borderWidth = selected and 1 or 0,
        radius = 12,
        onClick = function() openCategory(category) end,
    }, {
        ui.row({ width = 38, height = 38, align = "center", justify = "center", fill = "primary/0.13", radius = 11 }, {
            ui.glyph({ name = category.glyph, size = 21, color = "primary" }),
        }),
        ui.column({ gap = 2, flexGrow = 1 }, {
            ui.label({ text = category.title, fontSize = 15, fontWeight = "semibold", color = "on_surface" }),
            ui.label({ text = category.subtitle, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
        }),
        ui.glyph({ name = "chevron-right", size = 17, color = "on_surface_variant" }),
    })
end

local function goBack()
    local category = categoryById(currentCategory)
    currentCategory = category and category.parent or nil
    query = ""
    selectedIndex = 1
    resetScrollToTop()
    inputGeneration += 1
    render()
end

local function onSearchChanged(value)
    local nextQuery = value or ""
    -- A controlled input can report its current value again after panel.render.
    -- Rendering that unchanged value creates a feedback loop that resets arrow
    -- selection and eventually trips Noctalia's repeated-timeout circuit breaker.
    if nextQuery == query then return end
    query = nextQuery
    selectedIndex = 1
    resetScrollToTop()
    render()
end

local function onSearchSubmitted(value)
    query = value or ""
    local items = matchingItems()
    activateItem(items[selectedIndex] or items[1])
end

function onKey(chord, pressed)
    if not pressed or not isOpen then return end

    local items = matchingItems()
    if chord == "down" and #items > 0 then
        selectedIndex = (selectedIndex % #items) + 1
        followSelection(#items)
        render(items)
    elseif chord == "up" and #items > 0 then
        selectedIndex = ((selectedIndex - 2) % #items) + 1
        followSelection(#items)
        render(items)
    elseif chord == "return" or chord == "right" then
        activateItem(items[selectedIndex] or items[1])
    elseif chord == "alt+left" and currentCategory ~= nil then
        goBack()
    end
end

render = function(precomputedItems)
    if not isOpen then return end

    local activeCategory = categoryById(currentCategory)
    local title = activeCategory and activeCategory.title or "Command Center"
    local subtitle = activeCategory and activeCategory.subtitle or "Search applications and system commands"
    local headerChildren = {}

    if currentCategory ~= nil then
        headerChildren[#headerChildren + 1] = ui.button({ glyph = "arrow-left", variant = "ghost", tooltip = "Back", onClick = goBack })
    else
        headerChildren[#headerChildren + 1] = ui.row({ width = 38, height = 38, align = "center", justify = "center", fill = "primary/0.14", radius = 11 }, {
            ui.glyph({ name = "command", size = 21, color = "primary" }),
        })
    end

    headerChildren[#headerChildren + 1] = ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = title, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
        ui.label({ text = subtitle, fontSize = 11, color = "on_surface_variant" }),
    })
    headerChildren[#headerChildren + 1] = ui.button({ glyph = "x", variant = "ghost", tooltip = "Close", onClick = function() panel.close() end })

    local items = precomputedItems or matchingItems()
    if #items == 0 then
        selectedIndex = 1
    elseif selectedIndex > #items then
        selectedIndex = #items
    end
    local rows = {}
    if #items == 0 then
        local status = applicationsLoading and "Indexing applications…" or "No matching applications or commands"
        rows[#rows + 1] = ui.column({ align = "center", paddingV = 54, gap = 10 }, {
            ui.glyph({ name = applicationsLoading and "loader-2" or "search-off", size = 30, color = "on_surface_variant" }),
            ui.label({ text = status, fontSize = 13, color = "on_surface_variant" }),
        })
    else
        for index, item in ipairs(items) do
            local selected = not keyboardContextVisible and index == selectedIndex
            rows[#rows + 1] = (item.dispatch ~= nil or item.path ~= nil) and resultRow(item, selected) or categoryRow(item, selected)
        end

        if keyboardContextVisible then
            rows[#rows + 1] = ui.row({ key = "keyboard-context-heading", height = 28, align = "center", gap = 9, paddingH = 4 }, {
                ui.separator({ flexGrow = 1 }),
                ui.label({ text = "Keyboard selection", fontSize = 10, color = "on_surface_variant" }),
                ui.separator({ flexGrow = 1 }),
            })

            local firstContextIndex = math.max(1, selectedIndex - KEYBOARD_CONTEXT_ROWS + 1)
            for index = firstContextIndex, selectedIndex do
                local item = items[index]
                rows[#rows + 1] = (item.dispatch ~= nil or item.path ~= nil)
                    and resultRow(item, index == selectedIndex, "keyboard-context-")
                    or categoryRow(item, index == selectedIndex)
            end
        end
    end

    panel.render(ui.column({ flexGrow = 1, padding = 16, gap = 12 }, {
        ui.row({ align = "center", gap = 11 }, headerChildren),
        ui.row({ height = 48, align = "center", gap = 9, paddingH = 12, fill = "surface_variant/0.58", radius = 12 }, {
            ui.glyph({ name = "search", size = 19, color = "primary" }),
            ui.input({
                key = "command-search-" .. tostring(inputGeneration),
                value = query,
                placeholder = activeCategory and ("Search " .. string.lower(activeCategory.title) .. " or all commands…") or "Search applications and commands…",
                fontSize = 14,
                frameVisible = false,
                focus = true,
                flexGrow = 1,
                onChange = onSearchChanged,
                onSubmit = onSearchSubmitted,
            }),
        }),
        ui.scroll({
            key = "command-results-" .. tostring(scrollGeneration),
            flexGrow = 1,
            gap = 7,
            scrollToBottomRev = scrollAtBottom and scrollToBottomRevision or nil,
        }, rows),
        ui.row({ align = "center", justify = "space_between", paddingH = 3 }, {
            ui.label({ text = applicationsLoaded and (tostring(#applications) .. " applications indexed") or "Loading applications", fontSize = 10, color = "on_surface_variant" }),
            ui.label({ text = "↑↓ navigate  ·  →/Enter select  ·  Alt+← back  ·  Esc close", fontSize = 10, color = "on_surface_variant" }),
        }),
    }))
end

local function loadApplications()
    if applicationsLoading or applicationsLoaded then return end
    applicationsLoading = true
    local script = noctalia.pluginDir() .. "/list-applications.sh"
    noctalia.runAsync({ script }, function(result)
        applicationsLoading = false
        if result.exitCode ~= 0 then
            noctalia.log("command-center application index failed: " .. (result.stderr or "unknown error"))
            if isOpen then render() end
            return
        end

        local loaded = {}
        for line in string.gmatch(result.stdout or "", "[^\n]+") do
            local fields = splitTabs(line)
            if #fields >= 5 then
                loaded[#loaded + 1] = {
                    id = fields[1],
                    title = fields[2],
                    subtitle = fields[3],
                    icon = fields[4],
                    path = fields[5],
                    glyph = "app-window",
                }
            end
        end
        applications = loaded
        applicationsLoaded = true
        if isOpen then render() end
    end, 10000)
end

function onOpen(_context)
    isOpen = true
    query = ""
    currentCategory = nil
    selectedIndex = 1
    resetScrollToTop()
    inputGeneration += 1
    render()
    loadApplications()
end

function onClose()
    isOpen = false
end

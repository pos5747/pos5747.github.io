--[[---------------------------------------------------------------------------
exercises.lua -- reveal buttons and timed solutions for the weekly exercises

WHAT IT DOES

  * Numbers the exercises continuously ("Exercise 1", "Exercise 2", ...)
    across the topic sections, the way the PDF version does, and restarts as
    "Extra Practice 1" after the `# ... {.extra-practice}` heading.  The
    numbers come from document order, so reordering or deleting an exercise
    renumbers the rest, and their `#ex-N` anchors, on the next render.

  * Fills in `[]{.ex-count}` with the number of exercises on the page, so a
    sentence like "Do all []{.ex-count} exercises below" cannot go stale.

  * Resolves cross-references.  Tag an exercise `## Title {ref="key"}` and
    write `[key]{.ex-ref}` anywhere on the page; it renders as a link reading
    "Exercise 4".  Both the number and the link target are worked out at
    render time, so neither can drift when the exercises are reordered.

  * Turns `::: hint` and `::: sol` divs into reveal buttons.  Authors write
    plain fenced divs; every bit of markup lives here.

    The layer is `sol`, not `solution`: Quarto reserves `solution` for its
    proof environments and strips the class -- and the content with it --
    before any user filter runs.  A `::: solution` div therefore vanishes
    silently, so the filter warns when it sees a div with no classes.

  * Holds the solution buttons back until a release moment computed from the
    document's `distributed:` date.  See _metadata.yml for the knobs.

METADATA (all optional except `distributed`)

  distributed            2026-08-25   the day the set goes out
  exercise-level         2            heading level that marks an exercise
  solution-delay-days    5            days from `distributed` to release
  solution-unlock-time   "17:00"      time of day, 24-hour, Eastern
  solution-unlock        ""           explicit "YYYY-MM-DD HH:MM" override
  solution-gate          render       "render" or "browser" (see below)
  show-hints             draft        true | draft | false.  `true` shows the
                                      hints that are written; `draft` also
                                      shows `::: {.hint .todo}` placeholders,
                                      marked as such; `false` hides the lot.

THE TWO GATES

  render   Before the release moment the solution text is left out of the
           HTML altogether; students see a disabled button naming the time.
           Re-render after the moment passes and the solutions appear.
           Nothing to peek at.  This is the default.

  browser  The solution text ships in the page and a script reveals it at the
           release moment, to the second, with no re-render.  Convenient, but
           anyone who opens the page source can read it early.

TIME ZONE

  Everything is America/New_York.  The offset is derived from the US rule
  (EDT from the second Sunday in March to the first Sunday in November), so
  the result does not depend on the clock of the machine doing the render.
-----------------------------------------------------------------------------]]

if not FORMAT:match("html") then return {} end

local stringify = pandoc.utils.stringify

-- ---------------------------------------------------------------- calendar --
-- Howard Hinnant's civil-date algorithms.  Self-contained on purpose: os.time
-- with a broken-down table applies the *renderer's* time zone, which is the
-- bug this whole section exists to avoid.

local function days_from_civil(y, m, d)
  y = (m <= 2) and (y - 1) or y
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m + ((m > 2) and -3 or 9)) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

local function civil_from_days(z)
  z = z + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524)
                          - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + ((mp < 10) and 3 or -9)
  if m <= 2 then y = y + 1 end
  return y, m, d
end

-- 0 = Sunday
local function weekday(y, m, d)
  return (days_from_civil(y, m, d) + 4) % 7
end

-- day-of-month of the nth Sunday in the given month
local function nth_sunday(y, m, n)
  local delta = (7 - weekday(y, m, 1)) % 7
  return 1 + delta + (n - 1) * 7
end

-- -4 during EDT, -5 during EST
local function eastern_offset(y, m, d, h)
  local stamp = (m * 100 + d) * 100 + h
  local starts = (3 * 100 + nth_sunday(y, 3, 2)) * 100 + 2
  local ends   = (11 * 100 + nth_sunday(y, 11, 1)) * 100 + 2
  return (stamp >= starts and stamp < ends) and -4 or -5
end

local MONTHS = { "January", "February", "March", "April", "May", "June",
                 "July", "August", "September", "October", "November",
                 "December" }
local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
               "Friday", "Saturday" }

local function pretty(y, m, d, hh, mm)
  local ampm = (hh < 12) and "AM" or "PM"
  local h12 = hh % 12
  if h12 == 0 then h12 = 12 end
  local clock = (mm == 0) and string.format("%d:00 %s", h12, ampm)
                          or string.format("%d:%02d %s", h12, mm, ampm)
  return string.format("%s, %s %d at %s",
                       DAYS[weekday(y, m, d) + 1], MONTHS[m], d, clock)
end

local function terse(y, m, d, hh, mm)
  local ampm = (hh < 12) and "am" or "pm"
  local h12 = hh % 12
  if h12 == 0 then h12 = 12 end
  local clock = (mm == 0) and string.format("%d%s", h12, ampm)
                          or string.format("%d:%02d%s", h12, mm, ampm)
  return string.format("%s %d, %s", MONTHS[m]:sub(1, 3), d, clock)
end

-- ------------------------------------------------------------ config state --

local CFG = {
  ex_level   = 2,      -- heading level that marks one exercise
  count      = 0,      -- how many exercises the page turned out to have
  refs       = {},     -- ref="key" on a heading -> its number and anchor
  unlocked   = true,   -- has the release moment passed at render time?
  gate       = "render",
  show_hints = "draft",
  iso        = nil,    -- release moment, ISO 8601 with offset
  pretty     = nil,    -- "Sunday, August 30 at 5:00 PM"
  terse      = nil,    -- "Aug 30, 5pm"
  configured = false,  -- did we find a `distributed:` date?
}

local function meta_string(meta, key, default)
  local v = meta[key]
  if v == nil then return default end
  local s = stringify(v)
  if s == "" then return default end
  return s
end

function Meta(meta)
  CFG.ex_level = tonumber(meta_string(meta, "exercise-level", "2")) or 2
  CFG.gate = meta_string(meta, "solution-gate", "render")
  CFG.show_hints = meta_string(meta, "show-hints", "draft")

  local y, mo, d, hh, mm

  local explicit = meta_string(meta, "solution-unlock", "")
  if explicit ~= "" then
    y, mo, d, hh, mm = explicit:match("^(%d%d%d%d)-(%d%d?)-(%d%d?)[ T](%d%d?):(%d%d)")
  else
    local given = meta_string(meta, "distributed", "")
    local dy, dm, dd = given:match("^(%d%d%d%d)-(%d%d?)-(%d%d?)")
    if dy then
      local delay = tonumber(meta_string(meta, "solution-delay-days", "5")) or 5
      y, mo, d = civil_from_days(days_from_civil(tonumber(dy), tonumber(dm),
                                                 tonumber(dd)) + delay)
      hh, mm = meta_string(meta, "solution-unlock-time", "17:00"):match("^(%d%d?):(%d%d)")
    end
  end

  if not (y and hh) then return nil end   -- no date: leave solutions open

  y, mo, d = tonumber(y), tonumber(mo), tonumber(d)
  hh, mm = tonumber(hh), tonumber(mm)

  local offset = eastern_offset(y, mo, d, hh)
  local release = days_from_civil(y, mo, d) * 86400 + hh * 3600 + mm * 60
                  - offset * 3600

  CFG.configured = true
  CFG.unlocked = os.time() >= release
  CFG.iso = string.format("%04d-%02d-%02dT%02d:%02d:00%+03d:00",
                          y, mo, d, hh, mm, offset)
  CFG.pretty = pretty(y, mo, d, hh, mm)
  CFG.terse = terse(y, mo, d, hh, mm)
  return nil
end

-- ----------------------------------------------------------------- markup --

local function raw(html) return pandoc.RawBlock("html", html) end

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
           :gsub('"', "&quot;"))
end

local LOCK = '<svg class="ex-lock" viewBox="0 0 16 16" aria-hidden="true">'
          .. '<path d="M4.5 7V5a3.5 3.5 0 1 1 7 0v2H12a1 1 0 0 1 1 1v5a1 1 0'
          .. ' 0 1-1 1H4a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1h.5Zm1.5 0h4V5a2 2 0 1'
          .. ' 0-4 0v2Z"/></svg>'

-- a <details> block whose summary looks like a button
local function reveal(kind, label, blocks, extra_class)
  local classes = "ex-reveal ex-reveal-" .. kind
  if extra_class then classes = classes .. " " .. extra_class end
  local out = pandoc.List()
  out:insert(raw('<details class="' .. classes .. '">'
                 .. '<summary class="ex-btn ex-btn-' .. kind .. '">'
                 .. '<span class="ex-btn-label">' .. esc(label) .. '</span>'
                 .. '</summary>'
                 .. '<div class="ex-reveal-body">'))
  out:extend(blocks)
  out:insert(raw('</div></details>'))
  return out
end

local function locked_button(label)
  return '<button type="button" class="ex-btn ex-btn-locked" disabled'
      .. ' aria-disabled="true">' .. LOCK
      .. '<span class="ex-btn-label">' .. esc(label) .. '</span>'
      .. '<span class="ex-btn-when">opens ' .. esc(CFG.terse) .. '</span>'
      .. '</button>'
end

-- the solution layer, in whichever of its three states applies
local function solution_block(label, blocks)
  if CFG.unlocked or not CFG.configured then
    return reveal("sol", label, blocks)
  end

  if CFG.gate == "browser" then
    local out = pandoc.List()
    out:insert(raw('<div class="ex-slot ex-pending" data-unlock="'
                   .. CFG.iso .. '">' .. locked_button(label)))
    out:extend(reveal("sol", label, blocks))
    out:insert(raw("</div>"))
    return out
  end

  -- gate == "render": the text simply is not here yet
  return pandoc.List({ raw('<div class="ex-slot">' .. locked_button(label)
                           .. "</div>") })
end

-- ------------------------------------------------------------ the document --

function Pandoc(doc)
  local blocks = doc.blocks
  local out = pandoc.List()

  local extra = false          -- past the "extra practice" divider?
  local number = 0             -- exercise counter
  local hint_i, hint_n = 0, 0  -- position and total within this exercise
  local sol_i, sol_n = 0, 0

  -- how many hint / solution divs belong to the exercise starting at `i`
  local function tally(i)
    local h, s = 0, 0
    for j = i + 1, #blocks do
      local b = blocks[j]
      if b.t == "Header" and b.level <= CFG.ex_level then break end
      if b.t == "Div" then
        -- only unlabelled hints are numbered, so a `label="Check your work"`
        -- tier does not turn "Hint" into "Hint 1"
        if b.classes:includes("hint") and not b.attributes["label"] then
          h = h + 1
        elseif b.classes:includes("sol") then s = s + 1 end
      end
    end
    return h, s
  end

  for i, block in ipairs(blocks) do
    if block.t == "Div" and #block.classes == 0 then
      io.stderr:write("exercises.lua: a fenced div arrived with no classes. "
        .. "Quarto reserves `solution`, `proof`, `remark`, and the theorem "
        .. "names, and strips them. Write `::: sol` instead.\n")
    end

    if block.t == "Header" and block.classes:includes("extra-practice") then
      extra = true
      number = 0
      block.classes = pandoc.List({ "ex-divider" })
      out:insert(block)

    elseif block.t == "Header" and block.level == CFG.ex_level then
      -- The number comes from the exercise's position in the document, never
      -- from anything in the source. Reorder or delete one and the rest
      -- renumber themselves, along with their #ex-N anchors.
      number = number + 1
      hint_i, sol_i = 0, 0
      hint_n, sol_n = tally(i)
      local word = extra and "Extra Practice " or "Exercise "
      block.identifier = (extra and "extra-" or "ex-") .. number
      block.classes:insert("ex-heading")
      if not extra then CFG.count = number end
      local key = block.attributes["ref"]
      if key then
        CFG.refs[key] = { label = word .. number, id = block.identifier }
        block.attributes["ref"] = nil   -- keep it out of the rendered tag
      end
      block.content:insert(1, pandoc.RawInline("html",
        '<span class="ex-num">' .. word .. number .. "</span> "))
      out:insert(block)

    elseif block.t == "Header" and block.level < CFG.ex_level then
      block.classes:insert("ex-section")
      out:insert(block)

    elseif block.t == "Div" and block.classes:includes("hint") then
      local todo = block.classes:includes("todo")
      local visible = (CFG.show_hints == "draft")
                   or (CFG.show_hints == "true" and not todo)
      if visible then
        -- `::: {.hint label="Check your work"}` overrides the auto label, so
        -- a tier that hands over an answer is not called "Hint 3".
        local label = block.attributes["label"]
        if not label then
          hint_i = hint_i + 1
          label = (hint_n > 1) and ("Hint " .. hint_i) or "Hint"
        end
        if todo then
          out:extend(reveal("hint", label .. " (draft)", block.content,
                            "ex-draft"))
        else
          out:extend(reveal("hint", label, block.content))
        end
      end

    elseif block.t == "Div" and block.classes:includes("sol") then
      sol_i = sol_i + 1
      local label = (sol_n > 1)
        and ("Complete solution, part " .. sol_i) or "Complete solution"
      out:extend(solution_block(label, block.content))

    else
      out:insert(block)
    end
  end

  -- release notice, directly under the title
  if CFG.configured then
    local notice
    if CFG.unlocked then
      notice = '<div class="ex-notice ex-notice-open">Complete solutions are '
            .. 'available. Work each exercise before you open one.</div>'
    else
      notice = '<div class="ex-notice ex-notice-wait" data-unlock="'
            .. CFG.iso .. '">Complete solutions open <strong>' .. esc(CFG.pretty)
            .. '</strong> <span class="ex-countdown"></span></div>'
    end
    out:insert(1, raw(notice))
  end

  doc.blocks = out
  return doc
end

-- Runs after Pandoc above, so the count and the ref table are settled.
local function Span(el)
  if el.classes:includes("ex-count") then
    return pandoc.Str(tostring(CFG.count))
  end

  if el.classes:includes("ex-ref") then
    local key = pandoc.utils.stringify(el)
    local target = CFG.refs[key]
    if not target then
      io.stderr:write('exercises.lua: [' .. key .. ']{.ex-ref} has no match. '
        .. 'Tag the exercise heading `## Title {ref="' .. key .. '"}`.\n')
      return pandoc.Str("Exercise ??")
    end
    return pandoc.Link(pandoc.Str(target.label), "#" .. target.id)
  end
end

return { { Meta = Meta }, { Pandoc = Pandoc }, { Span = Span } }

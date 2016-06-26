--[[
The MIT License (MIT)

Copyright (c) 2016 Christoph Kubisch

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]
local cmdlineargs = {...}
--local cmdlineargs = {"-addrace", "./results/test3.lua", "Race2.json", "-makehtml", "./results/test3.lua", "./results/test3.html"}

local cfg = {}

local function execEnvString(string, env)
  local fn,err = loadstring(string)
  assert(fn, err)
  fn = setfenv(fn, env)
  fn()
end

local function execEnv(filename, env)
  local fn,err = loadfile(filename)
  assert(fn, err)
  fn = setfenv(fn, env)
  fn()
end

execEnv("config.lua", cfg)

-------------------------------------------------------------------------------------
--

local printlog = print

local function tableFlatCopy(tab,fields)
  local tout = {}
  
  if (fields) then
    for i,v in pairs(fields) do
      tout[v] = tab[v]
    end
  else
    for i,v in pairs(tab) do
      tout[i] = v
    end
  end
  return tout
end

local function tableLayerCopy(tab,fields)
  local tout = {}
  
  for i,v in pairs(tab) do
    tout[i] = tableFlatCopy(v,fields)
  end
  
  return tout
end

local function quote(str)
  return str and '"'..tostring(str)..'"' or "nil"
end

local function ParseTime(str)
  if (not str) then return end
  local h,m,s = str:match("(%d+):(%d+):([0-9%.]+)")
  if (h and m and s) then return h*60*60 + m*60 + s end
  local m,s = str:match("(%d+):([0-9%.]+)")
  if (m and s) then return m*60 + s end
end

local function MakeTime(s, sep)
  local sep = sep or ":"
  local h = math.floor(s/3600)
  s = s - h*3600
  local m = math.floor(s/60)
  s = s - m*60
  
  return (h > 0 and tostring(h)..sep or "")..tostring(m)..sep..string.format("%#07.4f",s)
end

local function DiffTime(stra, strb)
  local ta = ParseTime(stra)
  local tb = ParseTime(strb)
  if (not (ta and tb)) then return end
  local diff = tb-ta
  local absdiff = math.abs(diff)
  
  local h = math.floor(absdiff/3600)
  absdiff = absdiff - h * 3600
  local m = math.floor(absdiff/60)
  absdiff = absdiff - m * 60
  local s = absdiff
  
  local sign = (diff >= 0 and "+" or "-")
  
  if (h > 0) then
    return sign..string.format(" %2d:%2d:%.3f", h,m,s)
  elseif (m > 0) then
    return sign.. string.format(" %2d:%.3f", m, s)
  else
    return sign.. string.format(" %.3f", s)
  end
  
end

-------------------------------------------------------------------------------------
--

local function outputTime(time)
  return string.format("%.8f", time):sub(1,-5).."0005"
end

local function computeTime(times)
  local avgtime  = 0
  local variance = 0
  local num = times and #times or 0
  if (num < 1) then return 0,0,0 end
  
  for i=1,num do
    avgtime = tonumber(times[i]) + avgtime
  end
  
  avgtime = avgtime / num
  local variance = 0
  for i=1,num do
    local diff = tonumber(times[i]) - avgtime
    variance = variance + diff*diff
  end
  variance = math.sqrt(variance)
  
  return num, avgtime, variance
end

-------------------------------------------------------------------------------------
--

local function parseAssets(filename)
  local f = io.open(filename,"rt")
  local str = f:read("*a")
  f:close()
  
  -- <optgroup label="ADAC GT Masters 2013">
  -- <option value="class-2922">
  
  local strclasses = str:match('<select name="car_class">(.-)</select>')

  printlog("Classes")
  local numClasses = 0
  local classes = {}
  local classesSorted = {}
  for name,id in strclasses:gmatch('<optgroup label="([^<>]-)">%s*<option value="class%-([^<>]-)">') do
    local tab = {name=name, id=id}
    table.insert(classesSorted, tab)
    classes[id] = tab
    printlog(id,name)
    numClasses = numClasses + 1
  end
  printlog(numClasses)
 
  -- <option value="5095" data-image="http://game.raceroom.com/de/assets/content/tracklayout/nordschleife-24-hours-5095-image-thumb.webp">
  -- Nordschleife - 24 Hours</option>
  
  local strtracks = str:match('<select name="track">(.-)</select>')
  
  printlog("Tracks")
  local tracks = {}
  local tracksSorted = {}
  local numTracks = 0
  for id,name in strtracks:gmatch('<option value="([^<>]-)".->%s*([^<>]-)</option>') do
    local tab = {name=name, id=id}
    table.insert(tracksSorted, tab)
    tracks[id] = tab
    printlog(id,name)
    numTracks = numTracks + 1
  end
  printlog(numTracks)
  
  return {
    classes=classes, 
    classesSorted=classesSorted, 
    tracks=tracks, 
    tracksSorted=tracksSorted,
    numClasses=numClasses, 
    numTracks=numTracks
  }
end
local function makeIcon(url,name,style)
  return '<img src="'..url..'" alt="'..name..'" title="'..name..'" style="vertical-align:middle;'..(style or "")..'" >'
end

local assets = parseAssets("assets.txt")


-------------------------------------------------------------------------------------
--

do
  local database = {
    classes = {
      minAI = 120,
      maxAI = 80,
      -- id
      tracks = {
        -- id
        ailevels = {
          { },-- level times in seconds
        },
      },
    }
  }
end

-------------------------------------------------------------------------------------
--

local function GenerateStatsHTML(outfilename,database)
  assert(outfilename and database)
  
  printlog("generate HTML",outfilename)
  
  local f = io.open(outfilename,"wt")
 
  f:write([[
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
    <meta charset="utf-8"/>
    
  ]])
  if (cfg.embedStylesheet) then
    local sf = io.open(cfg.embedStylesheet, "rt")
    local str = sf:read("*a")
    f:write([[ 
      <style type="text/css">
      <!-- ]]
      ..str..[[ 
      -->
      </style>
    ]])
    sf:close()
  else
    f:write([[ 
      <link href='http://fonts.googleapis.com/css?family=Open+Sans:400,700' rel='stylesheet' type='text/css'>
      <link rel="stylesheet" href="]]..cfg.stylesheetfile..[[">
    ]])
  end
  f:write([[ 
    </head>
    <body>
    <span class="minor">Icons are linked directly from the game's official website</span>
    <h1>R3E AI Database</h1>
  ]])
  
  local trackEntries = 0
  local totalEntries = 0
  local totalTimes   = 0
  
  local function writeTrack(track, trackasset, entry, minAI, maxAI)
    f:write([[
      <tr]]..(entry%2 == 0 and ' class="even"' or "")..[[>
      <td class="name">]]..trackasset.name.." ("..trackasset.id..[[)</td>
    ]])
    
    local found = 0
    for ai = minAI, maxAI do
      local times = track.ailevels[ai] or {}
      local num,avgtime,variance = computeTime(times)
      local aitime 
      if (num > 0) then
        aitime = MakeTime(avgtime)..'<br><span class="minor">'..string.format("%.3f / %d", variance, num).."</span>"
        
        totalTimes   = totalTimes + num
        totalEntries = totalEntries + 1
        found = 1
      else
        aitime = ""
      end
     
      f:write([[
        <td class="time">]]..aitime..[[</td>
      ]])
    end
    
    trackEntries = trackEntries + found
  end
  
  local function writeClass(class, classasset)
    f:write([[
      <h2>]]..classasset.name.." ("..classasset.id..[[)</h2>
      <table>
      <tr>
      <th>Track</th>
      ]])
    
    local minAI = math.max(cfg.minAI,class.minAI)
    local maxAI = math.min(cfg.maxAI,class.maxAI)
    
    for ai = minAI, maxAI do
      f:write([[
        <th>]]..ai..[[</th>
      ]])
    end
    f:write([[
      </tr>
    ]])
    
    local tracks = {}
    
    local i = 0
    for _,trackasset in ipairs(assets.tracksSorted) do
      local track = class.tracks[trackasset.id]
      if (track) then
        writeTrack(track, trackasset, i, minAI, maxAI)
        i = i + 1
      end
    end
    
    f:write([[
      </table>
      <br>
    ]])
      
  end
  
  
  
  for _,classasset in ipairs(assets.classesSorted) do
    local class = database.classes[classasset.id]
    if (class) then
      writeClass(class, classasset)
    end
  end
    
  f:write([[
    Total (track * car * ai) Entries: ]]..totalEntries..string.format(" (%.2f%%)", totalEntries*100/(assets.numClasses*assets.numTracks*(cfg.maxAI-cfg.minAI)) )..[[ Times: ]]..totalTimes..[[<br> 
    Track (track * car)     Entries: ]]..trackEntries..string.format(" (%.2f%%)", trackEntries*100/(assets.numClasses*assets.numTracks) )..[[ 
    </body>
    </html>
  ]])
  f:close()
end

----------------------------------------------------------------------------------------------------------------
-- Internals

local lxml = dofile("xml.lua")

local function labellink(obj)
  for i,v in ipairs(obj) do
    if (type(v) == "table" and v.label) then
      obj[v.label] = v
      labellink(v)
    end
  end
end

local function parseAdaptive(filename, database, playertimes)
  local f = io.open(filename,"rt")
  if (not f) then 
    printlog("adaptive file not openable")
    return
  else
    printlog("apdative file parsing", filename)
  end
  
  local txt = f:read("*a")
  f:close()
  
  local xml = lxml.parse(txt)
  labellink(xml)
  
  if (not xml) then 
    printlog("could not decode")
    return
  end
  
--[[
<AiAdaptation ID="/aiadaptation">
  <latestVersion type="uint32">0</latestVersion>
  <custom>
    <!-- Index:0 -->
    <key type="int32">263</key>
    <value>
      <!-- Index:0 -->
      <key type="int32">253</key>
      <custom>
        <custom>
          <!-- Index:0 -->
          <custom type="float32">108.74433136</custom>
          <!-- Index:1 -->
          <custom type="float32">115.84943390</custom>
          <!-- Index:2 -->
          <custom type="float32">123.27467346</custom>
        </custom>
        <custom>
          <!-- Index:0 -->
          <key type="uint32">100</key>
          <custom>
            <custom type="float32">108.44427490</custom>
            <custom type="uint32">2</custom>
          </custom>
        </custom>
      </custom>
      ...
    </value>
]]
  
  local function iterate3(tab, fn)
    local num = tab and #tab or 0
    for i=1,num,3 do
      fn(tab[i], tab[i+1], tab[i+2])
    end
  end
  
  local function iterate2(tab, fn)
    local num = tab and #tab or 0
    for i=1,num,2 do
      fn(tab[i], tab[i+1])
    end
  end
  
  local tracklist = xml.AiAdaptation.custom
  
  local added = false
  
  iterate3(tracklist, function(trackindex, trackkey, trackvalue)
    local trackid = trackkey[1]
    
    if (assets.tracks[trackid]) then
      iterate3( trackvalue, function(classindex, classkey, classcustom)
        local classid = classkey[1]
        local playerentries = classcustom[1]
        local aientries = classcustom[2]
        
        if (assets.classes[classid]) then
          if (playertimes and playerentries and #playerentries > 0) then
            local class = playertimes.classes[classid] or {tracks={}}
            playertimes.classes[classid] = class
            local track = class.tracks[trackid] or {playertime=nil,}
            class.tracks[trackid] = track
            
            local mintime = 1000000
            iterate2(playerentries, function(playerindex, playercustom)
              local playertime = tonumber(playercustom[1])
              mintime = math.min(playertime, mintime)
            end)
            track.playertime = mintime
            printlog("playertime found", assets.classes[classid].name, assets.tracks[trackid].name, mintime)
          end
          
          if (aientries and #aientries > 0) then
            local class = database.classes[classid] or {tracks={}}
            local track = class.tracks[trackid] or {ailevels={}}
         
            iterate3(aientries, function(aiindex, aikey, aicustom)
              local aitime = aicustom[1][1]
              -- filter out values that were generated by the tool/manual
              if (aitime:match("000.$") or not aitime:match("%.........")) then 
                printlog("skipping: generated", trackid, classid, aitime)
                return 
              end
              
              local ailevel = tonumber(aikey[1])
              
              class.minAI = math.min(ailevel, class.minAI or ailevel)
              class.maxAI = math.max(ailevel, class.maxAI or ailevel)
              
              track.minAI = math.min(ailevel, track.minAI or ailevel)
              track.maxAI = math.max(ailevel, track.maxAI or ailevel)
              
              if (false and classid == "3375") then          
                printlog(trackid, classid, ailevel, aitime)
                printlog(class.minAI, class.maxAI)
              end
              local times = track.ailevels[ailevel] or {}
              track.ailevels[ailevel] = times
              
              local num = #times
              
              local found = false
              for i=1,num do
                if (times[i] == aitime) then 
                  found = true
                end
              end
              if not found then 
                added = true
                table.insert(times, aitime)
              else
                --printlog("skipping: found", trackid, classid, aitime)
              end
            end)
          
            if (track.maxAI) then
              class.tracks[trackid] = track
              database.classes[classid] = class
            end
          end
        end
      end)
    end
  end)
  
  return added
end

local function clearAdaptive(filename)
  local f = io.open(filename,"rt")
  assert(f,"file not found: "..filename)
  local xml = f:read("*a")
  f:close()
--[[
          <!-- Index:0 -->
          <key type="uint32">97</key>
          <custom>
            <custom type="float32">92.45950005</custom>
            <custom type="uint32">0</custom>
          </custom>
]]
  
  
  local xml,num = xml:gsub(
      '[^\n]+<!%-%- Index:%d+ %-%->%s+'..
      '<key type="uint32">%d+</key>%s+'..
      '<custom>%s+'..
      '  <custom type="float32">%d?%d%d%.%d%d%d%d000[4-6]</custom>%s+'..
      '  <custom type="uint32">%d+</custom>%s+'..
      '</custom>\n' 
    , function(str)
      --printlog(str)
      return ""
  end)
  
  if (num > 0) then
    printlog("cleared generated ai file", filename, num)
    local f = io.open(filename,"wt")
    f:write(xml)
    f:close()
  end
end

local function modifyAdaptive(filename, processed, trackid, classid, aifrom, aito, aispacing)
  
  local class = processed.classes[classid]
  if (not class) then
    printlog("processed class not found", classid)
    return
  end
  local track = class.tracks[trackid]
  if (not track) then
    printlog("processed track not found", trackid)
    return
  end
--[[
<AiAdaptation ID="/aiadaptation">
  <latestVersion type="uint32">0</latestVersion>
  <custom>
    <!-- Index:0 -->
    <key type="int32">263</key>
    <value>
      <!-- Index:0 -->
      <key type="int32">253</key>
      <custom>
        <custom>
          <!-- Index:0 -->
          <custom type="float32">108.74433136</custom>
          <!-- Index:1 -->
          <custom type="float32">115.84943390</custom>
          <!-- Index:2 -->
          <custom type="float32">123.27467346</custom>
        </custom>
        <custom>
          <!-- Index:0 -->
          <key type="uint32">100</key>
          <custom>
            <custom type="float32">108.44427490</custom>
            <custom type="uint32">2</custom>
          </custom>
        </custom>
      </custom>
      ...
    </value>
]]
  local f = io.open(filename,"rt")
  assert(f,"file not found: "..filename)
  local xml = f:read("*a")
  f:close()
  
  local found = false
  
  local xmlnew = xml:gsub('(<key type="int32">'..trackid..'</key>%s*<value>)(.-)(</value>)', 
  function(tpre,tracks,tpost)
    local tracks = tracks:gsub('(<key type="int32">'..classid..'</key>\n%s*<custom>\n)(.-)(\n      </custom>)',
    function(cpre,class,cpost)
      local class = class:gsub('(</custom>%s*<custom>)(.*)(\n%s*</custom>)$',
      function(apre,aold,apost)
        local anew = ""
        local indent = string.rep(' ',10)
        
        found = true
        
        local idx = 0
        for ai=aifrom,aito,aispacing do
          local num,time = computeTime(track.ailevels[ai])
          if (num > 0) then
            anew = anew.."\n"
            anew = anew..indent..'<!-- Index:'..idx..' -->\n'
            anew = anew..indent..'<key type="uint32">'..ai..'</key>\n'
            anew = anew..indent..'<custom>\n'
            anew = anew..indent..'  <custom type="float32">'..outputTime(time)..'</custom>\n'
            anew = anew..indent..'  <custom type="uint32">0</custom>\n'
            anew = anew..indent..'</custom>'
            idx = idx + 1
          end
        end
        
        return apre..anew..apost
      end)
      return cpre..class..cpost
    end)
    return tpre..tracks..tpost
  end)

  if (found) then
    printlog("modified ai file", "track",trackid,"class", classid, filename)
    local f = io.open(filename,"wt")
    f:write(xmlnew)
    f:close()
  else
    printlog("could not find","track", trackid, "class", classid)
  end
end

local matrix = require "matrix"

-- function to get the results
local function getresults( mtx )
  assert( #mtx+1 == #mtx[1], "Cannot calculate Results" )
  mtx:dogauss()
  -- tresults
  local cols = #mtx[1]
  local tres = {}
  for i = 1,#mtx do
    tres[i] = mtx[i][cols]
  end
  return unpack( tres )
end

-- fit.linear ( x_values, y_values )
-- fit a straight line
-- model (  y = a + b * x  )
-- returns a, b
local fit = {}
function fit.linear( x_values,y_values )
  -- x_values = { x1,x2,x3,...,xn }
  -- y_values = { y1,y2,y3,...,yn }
  
  -- values for A matrix
  local a_vals = {}
  -- values for Y vector
  local y_vals = {}

  for i,v in ipairs( x_values ) do
    a_vals[i] = { 1, v }
    y_vals[i] = { y_values[i] }
  end

  -- create both Matrixes
  local A = matrix:new( a_vals )
  local Y = matrix:new( y_vals )

  local ATA = matrix.mul( matrix.transpose(A), A )
  local ATY = matrix.mul( matrix.transpose(A), Y )

  local ATAATY = matrix.concath(ATA,ATY)

  return getresults( ATAATY )
end

-- fit.parabola ( x_values, y_values )
-- Fit a parabola
-- model (  y = a + b * x + c * x² )
-- returns a, b, c
function fit.parabola( x_values,y_values )
  -- x_values = { x1,x2,x3,...,xn }
  -- y_values = { y1,y2,y3,...,yn }

  -- values for A matrix
  local a_vals = {}
  -- values for Y vector
  local y_vals = {}

  for i,v in ipairs( x_values ) do
    a_vals[i] = { 1, v, v*v }
    y_vals[i] = { y_values[i] }
  end

  -- create both Matrixes
  local A = matrix:new( a_vals )
  local Y = matrix:new( y_vals )

  local ATA = matrix.mul( matrix.transpose(A), A )
  local ATY = matrix.mul( matrix.transpose(A), Y )

  local ATAATY = matrix.concath(ATA,ATY)

  return getresults( ATAATY )
end

local function trackGenerator(classid, trackid, track)
  if (not track.maxAI or (track.maxAI - track.minAI < cfg.testMinAIdiffs)) then return end
  local minNum,minTime,minVar = computeTime(track.ailevels[ track.minAI ])
  
  local x = {}
  local y = {}
  if (cfg.fitAll) then 
    for i= track.minAI,track.maxAI do
      local times = track.ailevels[ i ]
      local num = times and #times or 0
      for t=1,num do
        table.insert(x, i)
        table.insert(y, times[t])
      end
    end
  else
    for i= track.minAI,track.maxAI do
      local num,time,var = computeTime(track.ailevels[ i ])
      if (num > 0) then
        table.insert(x, i)
        table.insert(y, time)
      end
    end
  end
  
  local a,b,c = fit.linear(x,y)
  c = c or 0
  
  local function generator(t)
    return a + b * t + c * (t*t)
  end
  
  local tested = 0
  local passed = 0
  local threshold = minTime * cfg.testMaxTimePct
  if (cfg.fitAll) then 
    local lasttime
    for i= track.minAI,track.maxAI do
      local base = generator(i)
      local num,time,var = computeTime(track.ailevels[ i ])
      if (num > 0) then
        tested = tested + 1
        local diff = math.abs(base - time)
        if (diff < threshold) then
          passed = passed + 1
        end
      end
      if (base > (lasttime or base)) then
        printlog("track fails fit", "not monotonicly decreasing", "class", classid, "track", trackid)
        return
      end
      lasttime = base
    end
  else
    for i= track.minAI,track.maxAI do
      local base = generator(i)
      local times = track.ailevels[ i ]
      local num = times and #times or 0
      for t=1,num do
        local time = times[t]
        tested = tested + 1
        
        local diff = math.abs(base - time)
        if (diff < threshold) then
          passed = passed + 1
        end
      end
      if (base > (lasttime or base)) then
        printlog("track fails fit", "not monotonicly decreasing", "class", classid, "track", trackid)
        return
      end
      lasttime = base
    end
  end
  
  local accepted = tested - passed <= math.max(1,tested * cfg.testMaxFailsPct)
  if (not accepted) then
    printlog("track fails fit", "outliers", tested - passed, "class", classid, "track", trackid)
  end
  
  
  return accepted and generator
end

local function processDatabase(database)
  -- find track/car combos where we can derive ailevels
  
  local filtered = {classes ={} }
  
  for classid,class in pairs(database.classes) do
    for trackid,track in pairs(class.tracks) do
      local gen = trackGenerator(classid, trackid, track)
      if (gen) then
        local classf = filtered.classes[classid] or {tracks={}}
        filtered.classes[classid] = classf
        
        classf.minAI = 80
        classf.maxAI = 120
        
        local ailevels = {}
        for i=80,120 do
          ailevels[i] = { outputTime(gen(i)) }
        end
        
        local trackf =  {}
        classf.tracks[trackid] = trackf
        
        trackf.minAI = 80
        trackf.maxAI = 120
        trackf.ailevels = ailevels
        
        trackf.generator = generator
      end
    end
  end
  
  return filtered
end

---------------------------------------------

require("wx")
local serpent = require("serpent")

local database =  {classes = {}}
local playertimes =  {classes = {}}
do
  local f = io.open(cfg.outdir..cfg.databasefile,"rt")
  if (f) then
    local dbstr = f:read("*a")
    f:close()
    local ok,db = serpent.load(dbstr)
    if (ok and db and db.classes) then
      database = db
    end
  end
end

local function specialFilename(filename)
  local replacedirs = {
    USER_DOCUMENTS = wx.wxStandardPaths.Get():GetDocumentsDir(),
  }
  
  filename = filename:gsub("%$([%w_]+)%$", replacedirs)
  return filename
end

local function appendSeeds()
  printlog("appending seeds")
  
  -- iterate lua files
  local path = wx.wxGetCwd().."/"..cfg.seeddir
  local dir = wx.wxDir(path)
  local found, file = dir:GetFirst("*.xml", wx.wxDIR_FILES)
  local dirty = false
  
  local targetfile = specialFilename(cfg.targetfile)
  dirty = parseAdaptive(targetfile, database, playertimes)
  
  while found do
    dirty = parseAdaptive(cfg.seeddir..file, database) or dirty
    
    found, file = dir:GetNext()
  end
  
  if (dirty) then
    GenerateStatsHTML(cfg.outdir..cfg.reportfile, database)
    
    local f = io.open(cfg.outdir..cfg.databasefile,"wt")
    f:write( serpent.dump(database,{indent=' '}) )
    f:close()
  end
end


appendSeeds()

local processed = processDatabase(database)
GenerateStatsHTML(cfg.outdir..cfg.processedfile, processed)



local editenv = {
  specialFilename = specialFilename,
  modifyAdaptive = modifyAdaptive,
  clearAdaptive = clearAdaptive,
  processed = processed,
  database = database,
  print = printlog,
}

local argcnt = #cmdlineargs
if (argcnt > 1) then
  for i=1,argcnt do
    local arg = cmdlineargs[i]
    if arg:find("r3e-adaptive-ai-primer.lua",1,true) then
    elseif arg:match(".lua$") then
      execEnv(arg, editenv)
    end
  end
  return
end

-- debug
if (false) then
  clearAdaptive(specialFilename(cfg.targetfile))
  return
end

function main()
  -- create the frame window
  local ww = 820
  local wh = 840
  frame = wx.wxFrame( wx.NULL, wx.wxID_ANY, "R3E Apdative AI Primer",
                      wx.wxDefaultPosition, wx.wxSize(ww+16, wh),
                      wx.wxDEFAULT_FRAME_STYLE )

  -- show the frame window
  frame:Show(true)
  
  local panel = wx.wxPanel  ( frame, wx.wxID_ANY)
  frame.panel = panel    
  
  local targetfile = specialFilename(cfg.targetfile)

  if not targetfile or not wx.wxFileName(targetfile):FileExists() then
    local label = wx.wxStaticText(panel, wx.wxID_ANY, "Could not find R3E adaptive AI file:\n"..tostring(targetfile))
    frame.label = label
    printlog("error")
    return
  end
  
  local winUpper  = wx.wxWindow ( panel, wx.wxID_ANY)
  local winLower  = wx.wxWindow ( panel, wx.wxID_ANY)
  -- Give the scrollwindow enough size so sizer works when calling Fit()
  --winLower:SetScrollbars(15, 15, 400, 1000, 0, 0, false)

  local sizer = wx.wxBoxSizer(wx.wxVERTICAL)
  sizer:Add(winUpper, 0, wx.wxEXPAND)
  sizer:Add(winLower, 0, wx.wxEXPAND)
  panel:SetSizer(sizer)
  
  frame.sizer = sizer
  frame.winUpper = winUpper
  frame.winLower = winLower
  
  local lblfile = wx.wxStaticText(winUpper, wx.wxID_ANY, "R3E adaptive AI file found:\n"..targetfile, wx.wxPoint(8,8),  wx.wxSize(ww,30) )
  local lblmod  = wx.wxStaticText(winUpper, wx.wxID_ANY, "Modification:",                             wx.wxPoint(8,50), wx.wxSize(ww-8,16) )
  
  local btnapply  =    wx.wxButton(winUpper, wx.wxID_ANY, "Apply Selected Modification",  wx.wxPoint(8,70),        wx.wxSize(200,20))
  local btnremove =    wx.wxButton(winUpper, wx.wxID_ANY, "Remove all likely generated",         wx.wxPoint(ww-8-240,70), wx.wxSize(240,20))
 
  winUpper.lblfile = lblfile
  winUpper.lblmod  = lblmod
  winUpper.btnapply = btnapply
  winUpper.binremove = btnremove
  
  local class 
  local classid
  local trackid
  local ailevel
  local aifrom
  local aito
  local aiNumLevels = cfg.aiNumLevels
  local aiSpacing   = cfg.aiSpacing
  
  btnremove:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
    clearAdaptive(targetfile)
  end)
  
  btnapply:Connect( wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
    if (classid and trackid and ailevel) then
      modifyAdaptive(targetfile, processed, trackid, classid, aifrom, aito, aiSpacing)
    end
  end)
  
  local ctrlClass = wx.wxListCtrl(winLower, wx.wxID_ANY,
                          wx.wxPoint(8,8), wx.wxSize(200,700),
                          wx.wxLC_REPORT)
  ctrlClass:InsertColumn(0, "Classes")
  ctrlClass:SetColumnWidth(0,190)
  
  local ctrlTrack = wx.wxListCtrl(winLower, wx.wxID_ANY,
                          wx.wxPoint(8+200,8), wx.wxSize(450,700),
                          wx.wxLC_REPORT)
  ctrlTrack:InsertColumn(0, "Tracks")
  ctrlTrack:InsertColumn(1, "Player Best")
  ctrlTrack:SetColumnWidth(0,340)
  ctrlTrack:SetColumnWidth(1,100)
  
  local ctrlAI = wx.wxListCtrl(winLower, wx.wxID_ANY,
                          wx.wxPoint(8+200+450,8), wx.wxSize(150,700),
                          wx.wxLC_REPORT)
  ctrlAI:InsertColumn(0, "AI")
  ctrlAI:InsertColumn(1, "Time")
  ctrlAI:SetColumnWidth(0,30)
  ctrlAI:SetColumnWidth(1,110)
  
  local classids = {}
  local trackids = {}
  local ailevels = {}
  
  local function updateClasses()
    classid = nil
    classids = {}
    local i = 0
    ctrlClass:DeleteAllItems()
    for _,classasset in ipairs(assets.classesSorted) do
      local class = processed.classes[classasset.id]
      if (class) then
        ctrlClass:InsertItem(i, classasset.name)
        table.insert(classids, classasset.id)
        i = i + 1
        classid = classid or classasset.id
      end
    end
    ctrlClass:SetItemState(0, wx.wxLIST_STATE_SELECTED, wx.wxLIST_STATE_SELECTED)
  end
  
  local function updateTracks()
    trackid = nil
    trackids = {}
    local i = 0
    ctrlTrack:DeleteAllItems()
    for _,trackasset in ipairs(assets.tracksSorted) do
      local track = processed.classes[classid].tracks[trackasset.id]
      if (track) then
        ctrlTrack:InsertItem(i, trackasset.name)
        table.insert(trackids, trackasset.id)
        
        local palyerclass = playertimes and playertimes.classes[classid]
        local playertrack = palyerclass and palyerclass.tracks[trackasset.id]
        if (playertrack and playertrack.playertime) then
          ctrlTrack:SetItem(i, 1, MakeTime(playertrack.playertime, " : "))
        end
        
        i = i + 1
        trackid = trackid or trackasset.id
      end
    end
    ctrlTrack:SetItemState(0, wx.wxLIST_STATE_SELECTED, wx.wxLIST_STATE_SELECTED)
  end
  
  local function updateAI()
    if (not trackid) then return end
    ailevel = nil
    ailevels = {}
    local i = 0
    ctrlAI:DeleteAllItems()
    local track = processed.classes[classid].tracks[trackid]
    if (track) then
      for ai=track.minAI,track.maxAI do
        local num,time = computeTime(track.ailevels[ai])
        if (num > 0) then
          ctrlAI:InsertItem(i, tostring(ai))
          ctrlAI:SetItem(i, 1, MakeTime(time, " : "))
          table.insert(ailevels, ai)
          i = i + 1
          ailevel = ailevel or ai
        end
      end
      ctrlAI:SetItemState(0, wx.wxLIST_STATE_SELECTED, wx.wxLIST_STATE_SELECTED)
    end
  end
  
  local function updateSelection()
    aifrom = math.max( 80,ailevel - math.floor(aiNumLevels/2))
    aito   = math.min(120,aifrom  + aiNumLevels - 1)
    lblmod:SetLabel("Modification: "..assets.classes[classid].name.." - "..assets.tracks[trackid].name.." : "..aifrom.." - "..aito.." step: "..aiSpacing)
  end
  
  updateClasses()
  updateTracks()
  updateAI()
  updateSelection()
  
  ctrlClass:Connect(wx.wxEVT_COMMAND_LIST_ITEM_SELECTED, function (event)
    local idx = event:GetIndex()
    classid = classids[idx + 1]
    updateTracks()
  end)

  ctrlTrack:Connect(wx.wxEVT_COMMAND_LIST_ITEM_SELECTED, function (event)
    local idx = event:GetIndex()
    trackid = trackids[idx + 1]
    updateAI()
  end)

  ctrlAI:Connect(wx.wxEVT_COMMAND_LIST_ITEM_SELECTED, function (event)
    local idx = event:GetIndex()
    ailevel = ailevels[idx + 1]
    updateSelection()
  end)

  sizer:Fit(panel)
end

main()
wx.wxGetApp():MainLoop()

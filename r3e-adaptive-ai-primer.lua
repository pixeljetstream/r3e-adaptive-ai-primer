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

local function loadConfigString(string)
  local fn,err = loadstring(string)
  assert(fn, err)
  fn = setfenv(fn, cfg)
  fn()
end

local function loadConfig(filename)
  local fn,err = loadfile(filename)
  assert(fn, err)
  fn = setfenv(fn, cfg)
  fn()
end

loadConfig("config.lua")

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

local function MakeTime(s)
  local h = math.floor(s/3600)
  s = s - h*3600
  local m = math.floor(s/60)
  s = s - m*60
  
  return (h > 0 and tostring(h)..":" or "")..tostring(m)..":"..string.format("%.4f",s)
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

local function ParseAdaptive(filename, database)
  local f = io.open(filename,"rt")
  if (not f) then 
    printlog("race file not openable")
    return
  else
    printlog("parsing", filename)
  end
  
  local txt = f:read("*a")
  f:close()
  
  local xml = lxml.parse(txt)
  
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
        local aientries = classcustom[2]
        
        if (assets.classes[classid]) then
          if (aientries and #aientries > 0) then
            local class = database.classes[classid] or {tracks={}}
            database.classes[classid] = class
            
            local track = class.tracks[trackid] or {ailevels={}}
            class.tracks[trackid] = track
          
            iterate3(aientries, function(aiindex, aikey, aicustom)
              local aitime = aicustom[1][1]
              if (aitime:match("000.$")) then return end
              
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
              end
            end)
          end
        end
      end)
    end
  end)
  
  return added
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
local function fitlinear( x_values,y_values )
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
local function fitparabola( x_values,y_values )
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
  if (track.maxAI - track.minAI < cfg.testMinAIdiffs) then return end
  local minNum,minTime,minVar = computeTime(track.ailevels[ track.minAI ])
  
  local x = {}
  local y = {}
  for i= track.minAI,track.maxAI do
    local num,time,var = computeTime(track.ailevels[ i ])
    if (num > 0) then
      table.insert(x, i)
      table.insert(y, time)
    end
  end
  
  local a,b,c = fitparabola(x,y)
  
  local tested = 0
  local passed = 0
  local threshold = minTime * cfg.testMaxTimePct
  for i= track.minAI,track.maxAI do
    local num,time,var = computeTime(track.ailevels[ i ])
    if (num > 0) then
      tested = tested + 1
      local base = a + b * i + c * (i*i)
      local diff = math.abs(base - time)
      if (diff < threshold) then
        passed = passed + 1
      end
    end
  end
  
  local accepted = tested - passed <= math.max(1,tested * cfg.testMaxFailsPct)
  if (not accepted) then
    printlog("track fails fit", "outliers", tested - passed, "class", classid, "track", trackid)
  end
  
  return accepted and {a=a,b=b,c=c}
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
          ailevels[i] = { outputTime(gen.a + gen.b * i + gen.c * i * i) }
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


require("wx")
local serpent = require("serpent")

local database =  {classes = {}}
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

local function appendSeeds()
  printlog("appending seeds")
  
  -- iterate lua files
  local path = wx.wxGetCwd().."/"..cfg.seeddir
  local dir = wx.wxDir(path)
  local found, file = dir:GetFirst("*.xml", wx.wxDIR_FILES)
  local dirty = false
  while found do
    dirty = ParseAdaptive(cfg.seeddir..file, database)
    
    found, file = dir:GetNext()
  end
  
  if (dirty) then
    GenerateStatsHTML(cfg.outdir..cfg.reportfile, database)
    
    local f = io.open(cfg.outdir..cfg.databasefile,"wt")
    f:write( serpent.dump(database) )
    f:close()
  end
end

appendSeeds()

local processed = processDatabase(database)
GenerateStatsHTML(cfg.outdir..cfg.processedfile, processed)

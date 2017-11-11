local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX                             = nil
local GUI                       = {}
GUI.Time                        = 0
local PlayerData                = {}
local FirstSpawn                = true
local IsDead                    = false
local HasAlreadyEnteredMarker   = false
local LastZone                  = nil
local CurrentAction             = nil
local CurrentActionMsg          = ''
local CurrentActionData         = {}
local RespawnToHospitalMenu     = nil
local OnJob                     = false
local CurrentCustomer           = nil
local CurrentCustomerBlip       = nil
local DestinationBlip           = nil
local IsNearCustomer            = false
local CustomerIsEnteringVehicle = false
local CustomerEnteredVehicle    = false
local TargetCoords              = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
  	if IsEntityDead(PlayerPedId())then
			StartScreenEffect("DeathFailOut", 0, 0)
			ShakeGameplayCam("DEATH_FAIL_IN_EFFECT_SHAKE", 1.0)

			local scaleform = RequestScaleformMovie("MP_BIG_MESSAGE_FREEMODE")

			if HasScaleformMovieLoaded(scaleform) then
				Citizen.Wait(0)

				PushScaleformMovieFunction(scaleform, "SHOW_SHARD_WASTED_MP_MESSAGE")
				BeginTextComponent("STRING")
				AddTextComponentString("~r~Vous êtes dans le coma")
				EndTextComponent()
				PopScaleformMovieFunctionVoid()

		  	Citizen.Wait(500)

		    while IsEntityDead(PlayerPedId()) do
					DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
			 		Citizen.Wait(0)
		    end

		  	StopScreenEffect("DeathFailOut")
			end
		end
	end
end)

function SetVehicleMaxMods(vehicle)

  local props = {
    modEngine       = 2,
    modBrakes       = 2,
    modTransmission = 2,
    modSuspension   = 3,
    modTurbo        = true,
  }

  ESX.Game.SetVehicleProperties(vehicle, props)

end

function DrawSub(msg, time)
  ClearPrints()
  SetTextEntry_2("STRING")
  AddTextComponentString(msg)
  DrawSubtitleTimed(time, 1)
end

function ShowLoadingPromt(msg, time, type)
  Citizen.CreateThread(function()
    Citizen.Wait(0)
    N_0xaba17d7ce615adbf("STRING")
    AddTextComponentString(msg)
    N_0xbd12f8228410d9b4(type)
    Citizen.Wait(time)
    N_0x10d373323e5b9c0d()
  end)
end

function GetRandomWalkingNPC()

  local search = {}
  local peds   = ESX.Game.GetPeds()

  for i=1, #peds, 1 do
    if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
      table.insert(search, peds[i])
    end
  end

  if #search > 0 then
    return search[GetRandomIntInRange(1, #search)]
  end

  print('Using fallback code to find walking ped')

  for i=1, 250, 1 do

    local ped = GetRandomPedAtCoord(0.0,  0.0,  0.0,  math.huge + 0.0,  math.huge + 0.0,  math.huge + 0.0,  26)

    if DoesEntityExist(ped) and IsPedHuman(ped) and IsPedWalking(ped) and not IsPedAPlayer(ped) then
      table.insert(search, ped)
    end

  end

  if #search > 0 then
    return search[GetRandomIntInRange(1, #search)]
  end

end

function ClearCurrentMission()

  if DoesBlipExist(CurrentCustomerBlip) then
    RemoveBlip(CurrentCustomerBlip)
  end

  if DoesBlipExist(DestinationBlip) then
    RemoveBlip(DestinationBlip)
  end

  CurrentCustomer           = nil
  CurrentCustomerBlip       = nil
  DestinationBlip           = nil
  IsNearCustomer            = false
  CustomerIsEnteringVehicle = false
  CustomerEnteredVehicle    = false
  TargetCoords              = nil

end

function StartAmbulanceJob()

  ShowLoadingPromt(_U('taking_service') .. 'Ambulance', 5000, 3)
  ClearCurrentMission()

  OnJob = true

end

function StopAmbulanceJob()

  local playerPed = GetPlayerPed(-1)

  if IsPedInAnyVehicle(playerPed, false) and CurrentCustomer ~= nil then
    local vehicle = GetVehiclePedIsIn(playerPed,  false)
    TaskLeaveVehicle(CurrentCustomer,  vehicle,  0)

    if CustomerEnteredVehicle then
      TaskGoStraightToCoord(CurrentCustomer,  TargetCoords.x,  TargetCoords.y,  TargetCoords.z,  1.0,  -1,  0.0,  0.0)
    end

  end

  ClearCurrentMission()

  OnJob = false

  DrawSub(_U('mission_complete'), 5000)

end

function RespawnPed(ped, coords)
  SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
  NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.heading, true, false)
  SetPlayerInvincible(ped, false)
  TriggerEvent('playerSpawned', coords.x, coords.y, coords.z, coords.heading)
  ClearPedBloodDamage(ped)
  if RespawnToHospitalMenu ~= nil then
    RespawnToHospitalMenu.close()
    RespawnToHospitalMenu = nil
  end
  ESX.UI.Menu.CloseAll()
end

RegisterNetEvent('esx_ambulancejob:heal')
AddEventHandler('esx_ambulancejob:heal', function(_type)
    local playerPed = GetPlayerPed(-1)
    local maxHealth = GetEntityMaxHealth(playerPed)
    if _type == 'small' then
        local health = GetEntityHealth(playerPed)
        local newHealth = math.min(maxHealth , math.floor(health + maxHealth/8))
        SetEntityHealth(playerPed, newHealth)
    elseif _type == 'big' then
        SetEntityHealth(playerPed, maxHealth)
    end
    ESX.ShowNotification(_U('healed'))
end)


function StartRespawnToHospitalMenuTimer()
  ESX.SetTimeout(Config.MenuRespawnToHospitalDelay, function()
    if IsDead then
      local elements = {}
      table.insert(elements, {label = _U('yes'), value = 'yes'})
      RespawnToHospitalMenu = ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'menuName',
        {
          title = _U('respawn_at_hospital'),
          align = 'top-left',
          elements = elements
        },
        function(data, menu) --Submit Cb
          menu.close()
          Citizen.CreateThread(function()
                  RemoveItemsAfterRPDeath()
                    end)
        end,
        function(data, menu) --Cancel Cb
          --menu.close()
        end,
        function(data, menu) --Change Cb
          --print(data.current.value)
        end,
        function(data, menu) --Close Cb
          RespawnToHospitalMenu = nil
        end
      )
    end
  end)
end

function StartRespawnTimer()
  ESX.SetTimeout(Config.RespawnDelayAfterRPDeath, function()
    if IsDead then
      RemoveItemsAfterRPDeath()
    end
  end)
end

function ShowTimer()
  local timer = Config.RespawnDelayAfterRPDeath
  Citizen.CreateThread(function()

    while timer > 0 and IsDead do
            Wait(0)

      raw_seconds = timer/1000
      raw_minutes = raw_seconds/60
      minutes = stringsplit(raw_minutes, ".")[1]
      seconds = stringsplit(raw_seconds-(minutes*60), ".")[1]

            SetTextFont(4)
            SetTextProportional(0)
            SetTextScale(0.0, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)

            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")

            local text = _U('please_wait') .. minutes .. _U('minutes') .. seconds .. _U('seconds')

            if Config.EarlyRespawn then
                text = text .. '\n[~b~E~w~]'
            end

            AddTextComponentString(text)
            SetTextCentre(true)
            DrawText(0.5, 0.8)

      if Config.EarlyRespawn then
        if IsControlPressed(0, Keys['E']) then
                    RemoveItemsAfterRPDeath()
                    break
        end
      end
            timer = timer - 15
    end

        if Config.EarlyRespawn then
        while timer <= 0 and IsDead do
          Wait(0)

                SetTextFont(4)
                SetTextProportional(0)
                SetTextScale(0.0, 0.5)
                SetTextColour(255, 255, 255, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)

                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")

                AddTextComponentString(_U('press_respawn'))
                SetTextCentre(true)
                DrawText(0.5, 0.8)

          if IsControlPressed(0, Keys['E']) then
            RemoveItemsAfterRPDeath()
                    break
          end
        end
        end

  end)
end

function RemoveItemsAfterRPDeath()
    Citizen.CreateThread(function()
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do
            Citizen.Wait(0)
        end
        ESX.TriggerServerCallback('esx_ambulancejob:removeItemsAfterRPDeath', function()

            ESX.SetPlayerData('lastPosition', Config.Zones.HospitalInteriorInside1.Pos)
            ESX.SetPlayerData('loadout', {})

            TriggerServerEvent('esx:updateLastPosition', Config.Zones.HospitalInteriorInside1.Pos)

            RespawnPed(GetPlayerPed(-1), Config.Zones.HospitalInteriorInside1.Pos)

            StopScreenEffect('DeathFailOut')
            DoScreenFadeIn(800)
            TriggerEvent('shakeCam', true)
        end)
    end)
end

--------add effect when the player come back after death-----
local time = 0
local shakeEnable = false

RegisterNetEvent('shakeCam')
AddEventHandler('shakeCam', function(status)
	if(status == true)then
		ShakeGameplayCam("FAMILY5_DRUG_TRIP_SHAKE", 1.0)
		shakeEnable = true
	elseif(status == false)then
		ShakeGameplayCam("FAMILY5_DRUG_TRIP_SHAKE", 0)
		shakeEnable = false
		time = 0
	end
end)

-----Enable/disable the effect by pills
Citizen.CreateThread(function()
	while true do 
		Wait(100)
		if(shakeEnable)then
			time = time + 100
			if(time > 5000)then -- 5 seconds
				TriggerEvent('shakeCam', false)
			end
		end
	end
end)


function OnPlayerDeath()
    IsDead = true
    if Config.ShowDeathTimer == true then
        ShowTimer()
    end
    StartRespawnTimer()
    if Config.RespawnToHospitalMenuTimer == true then
        StartRespawnToHospitalMenuTimer()
    end
    StartScreenEffect('DeathFailOut',  0,  false)
end

function TeleportFadeEffect(entity, coords)

  Citizen.CreateThread(function()

    DoScreenFadeOut(800)

    while not IsScreenFadedOut() do
      Citizen.Wait(0)
    end

    ESX.Game.Teleport(entity, coords, function()
      DoScreenFadeIn(800)
    end)

  end)

end

function WarpPedInClosestVehicle(ped)

  local coords = GetEntityCoords(ped)

  local vehicle, distance = ESX.Game.GetClosestVehicle({
    x = coords.x,
    y = coords.y,
    z = coords.z
  })

  if distance ~= -1 and distance <= 5.0 then

    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    local freeSeat = nil

    for i=maxSeats - 1, 0, -1 do
      if IsVehicleSeatFree(vehicle, i) then
        freeSeat = i
        break
      end
    end

    if freeSeat ~= nil then
      TaskWarpPedIntoVehicle(ped, vehicle, freeSeat)
    end

  else
  	ESX.ShowNotification(_U('no_vehicles'))
  end

end

function OpenAmbulanceActionsMenu()

  local elements = {
    {label = _U('cloakroom'), value = 'cloakroom'}
  }

  if Config.EnablePlayerManagement and PlayerData.job.grade_name == 'boss' then
    table.insert(elements, {label = _U('boss_actions'), value = 'boss_actions'})
  end

  ESX.UI.Menu.CloseAll()

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'ambulance_actions',
    {
      title    = _U('ambulance'),
      elements = elements
    },
    function(data, menu)

      if data.current.value == 'cloakroom' then
        OpenCloakroomMenu()
      end

      if data.current.value == 'boss_actions' then
        TriggerEvent('esx_society:openBossMenu', 'ambulance', function(data, menu)
          menu.close()
        end, {wash = true})
      end

    end,
    function(data, menu)

      menu.close()

      CurrentAction     = 'ambulance_actions_menu'
      CurrentActionMsg  = _U('open_menu')
      CurrentActionData = {}

    end
  )

end

function OpenMobileAmbulanceActionsMenu()

  ESX.UI.Menu.CloseAll()

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'mobile_ambulance_actions',
    {
      title    = _U('ambulance'),
      elements = {
        {label = _U('ems_menu'), value = 'citizen_interaction'},
      }
    },
    function(data, menu)

      if data.current.value == 'citizen_interaction' then

        ESX.UI.Menu.Open(
          'default', GetCurrentResourceName(), 'citizen_interaction',
          {
            title    = _U('ems_menu_title'),
            elements = {
              {label = _U('ems_menu_revive'),     value = 'revive'},
                            {label = _U('ems_menu_small'),      value = 'small'},
                            {label = _U('ems_menu_big'),        value = 'big'},
              {label = _U('ems_menu_putincar'),   value = 'put_in_vehicle'},
			  {label = _U('fine'),              value = 'fine'},
            }
          },
          function(data, menu)

            if data.current.value == 'revive' then
              menu.close()
              local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
              if closestPlayer == -1 or closestDistance > 3.0 then
                ESX.ShowNotification(_U('no_players'))
              else
                                ESX.TriggerServerCallback('esx_ambulancejob:getItemAmount', function(qtty)
                                    if qtty > 0 then
                        local closestPlayerPed = GetPlayerPed(closestPlayer)
                        local health = GetEntityHealth(closestPlayerPed)
                        if health == 0 then
                            local playerPed = GetPlayerPed(-1)
                            Citizen.CreateThread(function()
                              ESX.ShowNotification(_U('revive_inprogress'))
                              TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
                              Wait(10000)
                              ClearPedTasks(playerPed)
                              if GetEntityHealth(closestPlayerPed) == 0 then
                                                    TriggerServerEvent('esx_ambulancejob:removeItem', 'medikit')
                                TriggerServerEvent('esx_ambulancejob:revive', GetPlayerServerId(closestPlayer))
                                ESX.ShowNotification(_U('revive_complete'))
                              else
                                ESX.ShowNotification(_U('isdead'))
                              end
                            end)
                        else
                          ESX.ShowNotification(_U('unconscious'))
                        end
                                    else
                                        ESX.ShowNotification(_U('not_enough_medikit'))
                                    end
                                end, 'medikit')
				end
            end

                        if data.current.value == 'small' then
                            menu.close()
                            local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                            if closestPlayer == -1 or closestDistance > 3.0 then
                                ESX.ShowNotification(_U('no_players'))
                            else
                                ESX.TriggerServerCallback('esx_ambulancejob:getItemAmount', function(qtty)
                                    if qtty > 0 then
                                        local playerPed = GetPlayerPed(-1)
                                        Citizen.CreateThread(function()
                                            ESX.ShowNotification(_U('heal_inprogress'))
                                            TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
                                            Wait(10000)
                                            ClearPedTasks(playerPed)
                                            TriggerServerEvent('esx_ambulancejob:removeItem', 'bandage')
                                            TriggerServerEvent('esx_ambulancejob:heal', GetPlayerServerId(closestPlayer), 'small')
                                            ESX.ShowNotification(_U('heal_complete'))
                                        end)
                                    else
                                        ESX.ShowNotification(_U('not_enough_bandage'))
                                    end
                                end, 'bandage')
                            end
                        end

                        if data.current.value == 'big' then
                            menu.close()
                            local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
                            if closestPlayer == -1 or closestDistance > 3.0 then
                                ESX.ShowNotification(_U('no_players'))
                            else
                                ESX.TriggerServerCallback('esx_ambulancejob:getItemAmount', function(qtty)
                                    if qtty > 0 then
                                        local playerPed = GetPlayerPed(-1)
                                        Citizen.CreateThread(function()
                                            ESX.ShowNotification(_U('heal_inprogress'))
                                            TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
                                            Wait(10000)
                                            ClearPedTasks(playerPed)
                                            TriggerServerEvent('esx_ambulancejob:removeItem', 'medikit')
                                            TriggerServerEvent('esx_ambulancejob:heal', GetPlayerServerId(closestPlayer), 'big')
                                            ESX.ShowNotification(_U('heal_complete'))
                                        end)
                                    else
                                        ESX.ShowNotification(_U('not_enough_medikit'))
                                    end
                                end, 'medikit')
                            end
                        end

            if data.current.value == 'put_in_vehicle' then
              menu.close()
              WarpPedInClosestVehicle(GetPlayerPed(closestPlayer))
            end
						
			local player, distance = ESX.Game.GetClosestPlayer()
			
			if distance ~= -1 and distance <= 3.0 then
				if data.current.value == 'put_in_vehicle' then
					menu.close()
					TriggerServerEvent('esx_ambulancejob:putInVehicle', GetPlayerServerId(player))
				end
				
				if data.current.value == 'fine' then
					OpenFineMenu(player)
				end
			else
				ESX.ShowNotification(_U('no_players_nearby'))
			end

          end,
          function(data, menu)
            menu.close()
          end
        )

      end

    end,
    function(data, menu)
      menu.close()
    end
  )

end

function OpenFineMenu(player)

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'fine',
    {
      title    = _U('fine'),
      align    = 'top-left',
      elements = {
        {label = _U('ambulance_consultation'),   value = 0},
		{label = _U('ambulance_care'),   value = 1},
		{label = _U('ambulance_reanimation'),   value = 2},
      },
    },
    function(data, menu)

      OpenFineCategoryMenu(player, data.current.value)

    end,
    function(data, menu)
      menu.close()
    end
  )

end

function OpenFineCategoryMenu(player, category)

  ESX.TriggerServerCallback('esx_ambulancejob:getFineList', function(fines)

    local elements = {}

    for i=1, #fines, 1 do
      table.insert(elements, {
        label     = fines[i].label .. ' $' .. fines[i].amount,
        value     = fines[i].id,
        amount    = fines[i].amount,
        fineLabel = fines[i].label
      })
    end

    ESX.UI.Menu.Open(
      'default', GetCurrentResourceName(), 'fine_category',
      {
        title    = _U('fine'),
        align    = 'top-left',
        elements = elements,
      },
      function(data, menu)

        local label  = data.current.fineLabel
        local amount = data.current.amount

        menu.close()

        if Config.EnablePlayerManagement then
          TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), 'society_ambulance', _U('fine_total') .. label, amount)
        else
          TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(player), '', _U('fine_total') .. label, amount)
        end

        ESX.SetTimeout(300, function()
          OpenFineCategoryMenu(player, category)
        end)

      end,
      function(data, menu)
        menu.close()
      end
    )

  end, category)

end

function OpenCloakroomMenu()

  ESX.UI.Menu.Open(
    'default', GetCurrentResourceName(), 'cloakroom',
    {
      title    = _U('cloakroom'),
      align    = 'top-left',
      elements = {
        {label = _U('ems_clothes_civil'), value = 'citizen_wear'},
        {label = _U('ems_clothes_ems'), value = 'ambulance_wear'},
        {label = _U('sapeurun_wear'), value = 'sapeurun_wear'},
        {label = _U('secouriste_wear'), value = 'secouriste_wear'},
        {label = _U('samu_wear'), value = 'samu_wear'},
        {label = _U('sapeurdeux_wear'), value = 'sapeurdeux_wear'},
        {label = _U('sapeurtrois_wear'), value = 'sapeurtrois_wear'},
        {label = _U('sapeursauveteur_wear'), value = 'sapeursauveteur_wear'},
      },
    },
    function(data, menu)

      menu.close()

      if data.current.value == 'citizen_wear' then

        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
          TriggerEvent('skinchanger:loadSkin', skin)
        end)

      end
      
      if data.current.value == 'sapeursauveteur_wear' then --Ajout de tenue par grades

        Citizen.CreateThread(function()
    
    local model = GetHashKey("s_m_y_clown_01")

    RequestModel(model)
    while not HasModelLoaded(model) do
      RequestModel(model)
      Citizen.Wait(0)
    end
   
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
  end)

      end
      
      if data.current.value == 'sapeurtrois_wear' then --Ajout de tenue par grades

        Citizen.CreateThread(function()
    
    local model = GetHashKey("s_m_y_fireman_01")

    RequestModel(model)
    while not HasModelLoaded(model) do
      RequestModel(model)
      Citizen.Wait(0)
    end
   
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
  end)

      end
      
      if data.current.value == 'sapeurdeux_wear' then --Ajout de tenue par grades

        Citizen.CreateThread(function()
    
    local model = GetHashKey("s_m_y_waiter_01")

    RequestModel(model)
    while not HasModelLoaded(model) do
      RequestModel(model)
      Citizen.Wait(0)
    end
   
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
  end)

      end
      
      if data.current.value == 'samu_wear' then --Ajout de tenue par grades

        Citizen.CreateThread(function()
    
    local model = GetHashKey("s_m_m_hairdress_01")

    RequestModel(model)
    while not HasModelLoaded(model) do
      RequestModel(model)
      Citizen.Wait(0)
    end
   
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
  end)

      end
      
      if data.current.value == 'secouriste_wear' then --Ajout de tenue par grades

        Citizen.CreateThread(function()
    
    local model = GetHashKey("s_m_m_highsec_01")

    RequestModel(model)
    while not HasModelLoaded(model) do
      RequestModel(model)
      Citizen.Wait(0)
    end
   
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
  end)

      end
      
      if data.current.value == 'sapeurun_wear' then --Ajout de tenue par grades

        Citizen.CreateThread(function()
    
    local model = GetHashKey("s_m_m_paramedic_01")

    RequestModel(model)
    while not HasModelLoaded(model) do
      RequestModel(model)
      Citizen.Wait(0)
    end
   
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    
    RemoveAllPedWeapons(GetPlayerPed(-1), true)
  end)

      end

      if data.current.value == 'ambulance_wear' then

        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)

          if skin.sex == 0 then
            TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
          else
            TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
          end

        end)

      end

      CurrentAction     = 'ambulance_actions_menu'
      CurrentActionMsg  = _U('open_menu')
      CurrentActionData = {}

    end,
    function(data, menu)
      menu.close()
    end
  )

end

function OpenVehicleSpawnerMenu()

  ESX.UI.Menu.CloseAll()

  if Config.EnableSocietyOwnedVehicles then

    local elements = {}

    ESX.TriggerServerCallback('esx_society:getVehiclesInGarage', function(vehicles)

      for i=1, #vehicles, 1 do
        table.insert(elements, {label = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']', value = vehicles[i]})
      end

      ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'vehicle_spawner',
        {
          title    = _U('veh_menu'),
          align    = 'top-left',
          elements = elements,
        },
        function(data, menu)

          menu.close()

          local vehicleProps = data.current.value

          ESX.Game.SpawnVehicle(vehicleProps.model, Config.Zones.VehicleSpawnPoint.Pos, 270.0, function(vehicle)
            ESX.Game.SetVehicleProperties(vehicle, vehicleProps)
	    SetVehicleNumberPlateText(vehicle, "Ambu112")
            local playerPed = GetPlayerPed(-1)
            TaskWarpPedIntoVehicle(playerPed,  vehicle,  -1)
          end)

          TriggerServerEvent('esx_society:removeVehicleFromGarage', 'ambulance', vehicleProps)

        end,
        function(data, menu)

          menu.close()

          CurrentAction     = 'vehicle_spawner_menu'
          CurrentActionMsg  = _U('veh_spawn')
          CurrentActionData = {}

        end
      )

    end, 'ambulance')

  else

    ESX.UI.Menu.Open(
      'default', GetCurrentResourceName(), 'vehicle_spawner',
      {
        title    = _U('veh_menu'),
        align    = 'top-left',
        elements = {
          {label = _U('ambulance'),   value = 'ambulance'},
         -- {label = _U('audi'),   value = 'policeold1'},
         -- {label = _U('Laguna'),   value = '1225'},
         -- {label = _U('206'),   value = '1226'},
         -- {label = _U('land'),   value = '1227'},
          {label = _U('helicopter'), value = 'supervolito'},
         -- {label = _U('Echelle 2'), value = 'firetruk'},
         -- {label = _U('Croix rouge'), value = 'firetruck'},
         -- {label = _U('Lance incendie'), value = '1228'},
         -- {label = _U('VTU'), value = '1221'},
         -- {label = _U('VBS'), value = '1220'},
		  {label = _U('suvmedic'),  value = 'hwaycar4'}
        },
      },
      function(data, menu)
        menu.close()
        local model = data.current.value
        ESX.Game.SpawnVehicle(model, Config.Zones.VehicleSpawnPoint.Pos, 230.0, function(vehicle)
          local playerPed = GetPlayerPed(-1)
          TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
	  SetVehicleMaxMods(vehicle)
        end)
      end,
      function(data, menu)
        menu.close()
        CurrentAction     = 'vehicle_spawner_menu'
        CurrentActionMsg  = _U('veh_spawn')
        CurrentActionData = {}
      end
    )

  end

end

function OpenPharmacyMenu()
    ESX.UI.Menu.CloseAll()

    ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'pharmacy',
        {
            title    = _U('pharmacy_menu_title'),
            align    = 'top-left',
            elements = {
                {label = _U('pharmacy_take') .. ' ' .. _('medikit'),  value = 'medikit'},
                {label = _U('pharmacy_take') .. ' ' .. _('pills'),  value = 'pills'},
				{label = _U('pharmacy_take') .. ' ' .. _('bandage'),  value = 'bandage'}
            },
        },
        function(data, menu)
            TriggerServerEvent('esx_ambulancejob:giveItem', data.current.value)
        end,
        function(data, menu)
            menu.close()
            CurrentAction     = 'pharmacy'
            CurrentActionMsg  = _U('open_pharmacy')
            CurrentActionData = {}
        end
    )
end

AddEventHandler('playerSpawned', function()

  IsDead = false

  if FirstSpawn then
    exports.spawnmanager:setAutoSpawn(false)
    FirstSpawn = false
  end

end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
  PlayerData.job = job
end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)

  local specialContact = {
    name       = 'Ambulance',
    number     = 'ambulance',
    base64Icon = 'data:image/png;base64,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'
  }

  TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)

end)

AddEventHandler('baseevents:onPlayerDied', function(killerType, coords)
  OnPlayerDeath()
end)

AddEventHandler('baseevents:onPlayerKilled', function(killerId, data)
  OnPlayerDeath()
end)

RegisterNetEvent('esx_ambulancejob:revive')
AddEventHandler('esx_ambulancejob:revive', function()

  local playerPed = GetPlayerPed(-1)
  local coords    = GetEntityCoords(playerPed)

  Citizen.CreateThread(function()

    DoScreenFadeOut(800)

    while not IsScreenFadedOut() do
      Citizen.Wait(0)
    end

    ESX.SetPlayerData('lastPosition', {
      x = coords.x,
      y = coords.y,
      z = coords.z
    })

    TriggerServerEvent('esx:updateLastPosition', {
      x = coords.x,
      y = coords.y,
      z = coords.z
    })

    RespawnPed(playerPed, {
      x = coords.x,
      y = coords.y,
      z = coords.z
    })

    StopScreenEffect('DeathFailOut')

    DoScreenFadeIn(800)

  end)

end)

AddEventHandler('esx_ambulancejob:hasEnteredMarker', function(zone)

  if zone == 'HospitalInteriorEntering1' then
    TeleportFadeEffect(GetPlayerPed(-1), Config.Zones.HospitalInteriorInside1.Pos)
  end

  if zone == 'HospitalInteriorExit1' then
    TeleportFadeEffect(GetPlayerPed(-1), Config.Zones.HospitalInteriorOutside1.Pos)
  end

  if zone == 'HospitalInteriorEntering2' then
        local heli = Config.HelicopterSpawner

        if not IsAnyVehicleNearPoint(heli.SpawnPoint.x, heli.SpawnPoint.y, heli.SpawnPoint.z, 3.0)
            and PlayerData.job ~= nil and PlayerData.job.name == 'ambulance' then
            ESX.Game.SpawnVehicle('polmav', {
                x = heli.SpawnPoint.x,
                y = heli.SpawnPoint.y,
                z = heli.SpawnPoint.z
            }, heli.Heading, function(vehicle)
                SetVehicleModKit(vehicle, 0)
                SetVehicleLivery(vehicle, 1)
            end)

        end
    TeleportFadeEffect(GetPlayerPed(-1), Config.Zones.HospitalInteriorInside2.Pos)
  end

  if zone == 'HospitalInteriorExit2' then
    TeleportFadeEffect(GetPlayerPed(-1), Config.Zones.HospitalInteriorOutside2.Pos)
  end

    if zone == 'ParkingDoorGoOutInside' then
        TeleportFadeEffect(GetPlayerPed(-1), Config.Zones.ParkingDoorGoOutOutside.Pos)
    end

    if zone == 'ParkingDoorGoInOutside' then
        TeleportFadeEffect(GetPlayerPed(-1), Config.Zones.ParkingDoorGoInInside.Pos)
    end

    if zone == 'StairsGoTopBottom' then
        CurrentAction     = 'fast_travel_goto_top'
        CurrentActionMsg  = _U('fast_travel')
        CurrentActionData = {pos = Config.Zones.StairsGoTopTop.Pos}
    end

    if zone == 'StairsGoBottomTop' then
        CurrentAction     = 'fast_travel_goto_bottom'
        CurrentActionMsg  = _U('fast_travel')
        CurrentActionData = {pos = Config.Zones.StairsGoBottomBottom.Pos}
    end

  if zone == 'AmbulanceActions' then
    CurrentAction     = 'ambulance_actions_menu'
    CurrentActionMsg  = _U('open_menu')
    CurrentActionData = {}
  end

  if zone == 'VehicleSpawner' then
    CurrentAction     = 'vehicle_spawner_menu'
    CurrentActionMsg  = _U('veh_spawn')
    CurrentActionData = {}
  end

    if zone == 'Pharmacy' then
        CurrentAction     = 'pharmacy'
        CurrentActionMsg  = _U('open_pharmacy')
        CurrentActionData = {}
    end

  if zone == 'VehicleDeleter' then

    local playerPed = GetPlayerPed(-1)
    local coords    = GetEntityCoords(playerPed)

    if IsPedInAnyVehicle(playerPed,  false) then

      local vehicle, distance = ESX.Game.GetClosestVehicle({
        x = coords.x,
        y = coords.y,
        z = coords.z
      })

      if distance ~= -1 and distance <= 1.0 then

        CurrentAction     = 'delete_vehicle'
        CurrentActionMsg  = _U('store_veh')
        CurrentActionData = {vehicle = vehicle}

      end

    end

  end

end)

function FastTravel(pos)
    TeleportFadeEffect(GetPlayerPed(-1), pos)
end

AddEventHandler('esx_ambulancejob:hasExitedMarker', function(zone)
  ESX.UI.Menu.CloseAll()
  CurrentAction = nil
end)

-- Create blips
Citizen.CreateThread(function()

  local blip = AddBlipForCoord(Config.Blip.Pos.x, Config.Blip.Pos.y, Config.Blip.Pos.z)

  SetBlipSprite (blip, Config.Blip.Sprite)
  SetBlipDisplay(blip, Config.Blip.Display)
  SetBlipScale  (blip, Config.Blip.Scale)
  SetBlipColour (blip, Config.Blip.Colour)
  SetBlipAsShortRange(blip, true)

  BeginTextCommandSetBlipName("STRING")
  AddTextComponentString(_U('hospital'))
  EndTextCommandSetBlipName(blip)

end)

-- Display markers
Citizen.CreateThread(function()
  while true do
    Wait(0)

    local coords = GetEntityCoords(GetPlayerPed(-1))
    for k,v in pairs(Config.Zones) do
      if(v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
                if PlayerData.job ~= nil and PlayerData.job.name == 'ambulance' then
                    DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
                elseif k ~= 'AmbulanceActions' and k ~= 'VehicleSpawner' and k ~= 'VehicleDeleter'
                    and k ~= 'Pharmacy' and k ~= 'StairsGoTopBottom' and k ~= 'StairsGoBottomTop' then
                    DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)
                end
      end
    end
  end
end)

-- Activate menu when player is inside marker
Citizen.CreateThread(function()
  while true do
    Wait(0)
    local coords      = GetEntityCoords(GetPlayerPed(-1))
    local isInMarker  = false
    local currentZone = nil
    for k,v in pairs(Config.Zones) do
            if PlayerData.job ~= nil and PlayerData.job.name == 'ambulance' then
                if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
                    isInMarker  = true
                    currentZone = k
                end
            elseif k ~= 'AmbulanceActions' and k ~= 'VehicleSpawner' and k ~= 'VehicleDeleter'
                and k ~= 'Pharmacy' and k ~= 'StairsGoTopBottom' and k ~= 'StairsGoBottomTop' then
                if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
                    isInMarker  = true
                    currentZone = k
                end
            end
    end
    if isInMarker and not hasAlreadyEnteredMarker then
      hasAlreadyEnteredMarker = true
      lastZone                = currentZone
      TriggerEvent('esx_ambulancejob:hasEnteredMarker', currentZone)
    end
    if not isInMarker and hasAlreadyEnteredMarker then
      hasAlreadyEnteredMarker = false
      TriggerEvent('esx_ambulancejob:hasExitedMarker', lastZone)
    end

  end
end)

-- Key Controls
Citizen.CreateThread(function()
  while true do

    Citizen.Wait(0)

    if CurrentAction ~= nil then

      SetTextComponentFormat('STRING')
      AddTextComponentString(CurrentActionMsg)
      DisplayHelpTextFromStringLabel(0, 0, 1, -1)

      if IsControlJustReleased(0, Keys['E']) and PlayerData.job ~= nil and PlayerData.job.name == 'ambulance' then

        if CurrentAction == 'ambulance_actions_menu' then
          OpenAmbulanceActionsMenu()
        end

        if CurrentAction == 'vehicle_spawner_menu' then
          OpenVehicleSpawnerMenu()
        end

                if CurrentAction == 'pharmacy' then
                    OpenPharmacyMenu()
                end

                if CurrentAction == 'fast_travel_goto_top' or CurrentAction == 'fast_travel_goto_bottom' then
                    FastTravel(CurrentActionData.pos)
                end

        if CurrentAction == 'delete_vehicle' then
          if Config.EnableSocietyOwnedVehicles then
            local vehicleProps = ESX.Game.GetVehicleProperties(CurrentActionData.vehicle)
            TriggerServerEvent('esx_society:putVehicleInGarage', 'ambulance', vehicleProps)
          end
          ESX.Game.DeleteVehicle(CurrentActionData.vehicle)
        end

        CurrentAction = nil

      end

    end

   -- if IsControlJustReleased(0, Keys['F6']) and PlayerData.job ~= nil and PlayerData.job.name == 'ambulance' then
     -- OpenMobileAmbulanceActionsMenu()
    -- end
		
    if IsControlPressed(0,  Keys['DELETE']) and (GetGameTimer() - GUI.Time) > 150 then

      if OnJob then
        StopAmbulanceJob()
      else

        if PlayerData.job ~= nil and PlayerData.job.name == 'ambulance' then

          local playerPed = GetPlayerPed(-1)

          if IsPedInAnyVehicle(playerPed,  false) then

            local vehicle = GetVehiclePedIsIn(playerPed,  false)

            if PlayerData.job.grade >= 3 then
              StartAmbulanceJob()
            else
              if GetEntityModel(vehicle) == GetHashKey('ambulance') then
                StartAmbulanceJob()
              else
                ESX.ShowNotification(_U('must_in_ambulance'))
              end
            end

          else

            if PlayerData.job.grade >= 3 then
              ESX.ShowNotification(_U('must_in_vehicle'))
            else
              ESX.ShowNotification(_U('must_in_ambulance'))
            end

          end

        end

      end

      GUI.Time = GetGameTimer()

    end
    end
end)

-- Load unloaded IPLs
Citizen.CreateThread(function()
  LoadMpDlcMaps()
  EnableMpDlcMaps(true)
  RequestIpl('Coroner_Int_on') -- Morgue
end)

-- String string
function stringsplit(inputstr, sep)
  if sep == nil then
      sep = "%s"
  end
  local t={} ; i=1
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
      t[i] = str
      i = i + 1
  end
  return t
end

Citizen.CreateThread(function()

  while true do

    Citizen.Wait(0)

    local playerPed = GetPlayerPed(-1)

    if OnJob then

      if CurrentCustomer == nil then

        DrawSub(_U('drive_search_pass'), 5000)

        if IsPedInAnyVehicle(playerPed,  false) and GetEntitySpeed(playerPed) > 0 then

          local waitUntil = GetGameTimer() + GetRandomIntInRange(30000,  45000)

          while OnJob and waitUntil > GetGameTimer() do
            Citizen.Wait(0)
          end

          if OnJob and IsPedInAnyVehicle(playerPed,  false) and GetEntitySpeed(playerPed) > 0 then

            CurrentCustomer = GetRandomWalkingNPC()

            if CurrentCustomer ~= nil then

              CurrentCustomerBlip = AddBlipForEntity(CurrentCustomer)

              SetBlipAsFriendly(CurrentCustomerBlip, 1)
              SetBlipColour(CurrentCustomerBlip, 2)
              SetBlipCategory(CurrentCustomerBlip, 3)
              SetBlipRoute(CurrentCustomerBlip,  true)

              SetEntityAsMissionEntity(CurrentCustomer,  true, false)
              ClearPedTasksImmediately(CurrentCustomer)
              SetBlockingOfNonTemporaryEvents(CurrentCustomer, 1)

              local standTime = GetRandomIntInRange(60000,  180000)

              TaskStandStill(CurrentCustomer, standTime)

              ESX.ShowNotification(_U('customer_found'))

            end

          end

        end

      else

        if IsPedFatallyInjured(CurrentCustomer) then

          ESX.ShowNotification(_U('client_unconcious'))

          if DoesBlipExist(CurrentCustomerBlip) then
            RemoveBlip(CurrentCustomerBlip)
          end

          if DoesBlipExist(DestinationBlip) then
            RemoveBlip(DestinationBlip)
          end

          SetEntityAsMissionEntity(CurrentCustomer,  false, true)

          CurrentCustomer           = nil
          CurrentCustomerBlip       = nil
          DestinationBlip           = nil
          IsNearCustomer            = false
          CustomerIsEnteringVehicle = false
          CustomerEnteredVehicle    = false
      TargetCoords              = nil

        end

        if IsPedInAnyVehicle(playerPed,  false) then

          local vehicle          = GetVehiclePedIsIn(playerPed,  false)
          local playerCoords     = GetEntityCoords(playerPed)
          local customerCoords   = GetEntityCoords(CurrentCustomer)
          local customerDistance = GetDistanceBetweenCoords(playerCoords.x,  playerCoords.y,  playerCoords.z,  customerCoords.x,  customerCoords.y,  customerCoords.z)

          if IsPedSittingInVehicle(CurrentCustomer,  vehicle) then

            if CustomerEnteredVehicle then

              local targetDistance = GetDistanceBetweenCoords(playerCoords.x,  playerCoords.y,  playerCoords.z,  TargetCoords.x,  TargetCoords.y,  TargetCoords.z)

              if targetDistance <= 5.0 then

                TaskLeaveVehicle(CurrentCustomer,  vehicle,  0)

                ESX.ShowNotification(_U('arrive_dest'))

                TaskGoStraightToCoord(CurrentCustomer,  TargetCoords.x,  TargetCoords.y,  TargetCoords.z,  1.0,  -1,  0.0,  0.0)
                SetEntityAsMissionEntity(CurrentCustomer,  false, true)

                TriggerServerEvent('esx_taxijob:success')

                RemoveBlip(DestinationBlip)

                local scope = function(customer)
                  ESX.SetTimeout(60000, function()
                    DeletePed(customer)
                  end)
                end

                scope(CurrentCustomer)

                CurrentCustomer           = nil
                CurrentCustomerBlip       = nil
                DestinationBlip           = nil
                IsNearCustomer            = false
                CustomerIsEnteringVehicle = false
                CustomerEnteredVehicle    = false
                TargetCoords              = nil

              end

              if TargetCoords ~= nil then
                DrawMarker(1, TargetCoords.x, TargetCoords.y, TargetCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 2.0, 178, 236, 93, 155, 0, 0, 2, 0, 0, 0, 0)
              end

            else

              RemoveBlip(CurrentCustomerBlip)

              CurrentCustomerBlip = nil

              --TargetCoords = Config.JobLocations[GetRandomIntInRange(1,  #Config.JobLocations)]
        TargetCoords = {x = 1164.2872314453,y = -1536.1022949219,z = 38.400829315186 }

              local street = table.pack(GetStreetNameAtCoord(TargetCoords.x, TargetCoords.y, TargetCoords.z))
              local msg    = nil

              if street[2] ~= 0 and street[2] ~= nil then
                msg = string.format(_U('take_me_to_near', GetStreetNameFromHashKey(street[1]),GetStreetNameFromHashKey(street[2])))
              else
                msg = string.format(_U('take_me_to', GetStreetNameFromHashKey(street[1])))
              end

              ESX.ShowNotification(msg)

              DestinationBlip = AddBlipForCoord(TargetCoords.x, TargetCoords.y, TargetCoords.z)

              BeginTextCommandSetBlipName("STRING")
              AddTextComponentString("Destination")
              EndTextCommandSetBlipName(blip)

              SetBlipRoute(DestinationBlip,  true)

              CustomerEnteredVehicle = true

            end

          else

            DrawMarker(1, customerCoords.x, customerCoords.y, customerCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 2.0, 178, 236, 93, 155, 0, 0, 2, 0, 0, 0, 0)

            if not CustomerEnteredVehicle then

              if customerDistance <= 30.0 then

                if not IsNearCustomer then
                  ESX.ShowNotification(_U('close_to_client'))
                  IsNearCustomer = true
                end

              end

              if customerDistance <= 100.0 then

                if not CustomerIsEnteringVehicle then

                  ClearPedTasksImmediately(CurrentCustomer)

                  local seat = 2

                  for i=4, 0, 1 do
                    if IsVehicleSeatFree(vehicle,  seat) then
                      seat = i
                      break
                    end
                  end

                  TaskEnterVehicle(CurrentCustomer,  vehicle,  -1,  seat,  2.0,  1)

                  CustomerIsEnteringVehicle = true

                end

              end

            end

          end

        else

          DrawSub(_U('return_to_veh'), 5000)

        end

      end

    end

  end
end)

RegisterNetEvent('NB:openMenuAmbulance')
AddEventHandler('NB:openMenuAmbulance', function()
	OpenMobileAmbulanceActionsMenu()
end)
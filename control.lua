require "defines"

local trainstate_str = {
     [0] = "on path",
     [1] = "lost path",
     [2] = "no schedule",
     [3] = "no path",
     [4] = "arrive at signal",
     [5] = "wait at signal",
     [6] = "arrive at station",
     [7] = "wait at station",
     [8] = "switched to manual control",
     [9] = "manual control",
    [10] = "switched to auto control",
}

local riding_acceleration_str = {
    [0] = "nothing",
    [1] = "accelarating",
    [2] = "breaking",
    [3] = "reversing",
}

local riding_direction_str = {
    [0] = "left",
    [1] = "none",
    [2] = "right",
}

-- TODO for each player
local state = {
    active = false,
    is_front = true,

    last_rail = nil,
    next_rail = nil,
    
    tracks = {-2, 0, 3, 5},
    main_track = 2,

    behind = {0, 0, 0, 0},
    distance = {0, 0, 0, 0},
    add_distance = {0, 0, 0, 0},

}

script.on_event(defines.events.on_player_driving_changed_state, function(event)
  local player = game.players[event.player_index]
  local print = player.print 
  local vehicle = player.vehicle

  -- local state = global.state[event_player_index]
  state.active = false
  state.train = nil

  if vehicle == nil then return end
  if vehicle.name ~= "ght-crl" then return end

  local train = vehicle.train
  local n_carriages = #train.carriages

  -- check if we are a front or backmover
  local locomotives = train.locomotives
  local front_mover = false
  for i = 1, # locomotives.front_movers do
      if locomotives.front_movers[i] == vehicle then
          front_mover = true
      end
  end

  local at_front = false
  local is_first = nil
  if train.carriages[1] == vehicle then
      at_front = front_mover
      is_first = true
  elseif train.carriages[n_carriages] == vehicle then
      at_front = not front_mover
  end

  if not at_front then
      print("We do not sit at the front of the train!")
      return
  end

  state.active =    true
  state.is_front =  front_mover
  state.train =     train
  state.last_rail = nil
  state.next_rail = nil

  print("Let's lay some rails…" .. (is_first and " (front)" or " (back)"))
end)

local pf = {
    ["straight-rail"] = {
        [0] = {
            [0] = { 2,  0},
            [1] = { 2, -2},
            [2] = { 0,  2},
            [3] = { 2,  2},
            [5] = {-2,  2},
            [7] = {-2, -2},
        },
        [1] = {
            [0] = {-2,  0},
            [1] = {-2,  2},
            [2] = { 0, -2},
            [3] = {-2, -2},
            [5] = { 2, -2},
            [7] = { 2,  2},
        }
    },
    ["curved-rail"] = {
        [0] = {
            [0] = {-2,  2},
            [1] = {-2, -2},
            [2] = {-2, -2},
            [3] = { 2, -2},
            [4] = { 2, -2},
            [5] = { 2,  2},
            [6] = { 2,  2},
            [7] = {-2,  2},
        },
        [1] = {
            [0] = { 2, -2},
            [1] = { 2,  2},
            [2] = { 2,  2},
            [3] = {-2,  2},
            [4] = {-2,  2},
            [5] = {-2, -2},
            [6] = {-2, -2},
            [7] = { 2, -2},
        },
    },
}

local function get_parallel_rail(rail, pos) 
    -- pos > 0, on the right hand side
    -- pos < 0, on the left hand side

    local data = {
        type = rail.type,
        direction = rail.direction,
        drive_direction = rail.drive_direction,
        position = {
            x = rail.position.x,
            y = rail.position.y,
        }
    }

    local f = pf[rail.type][rail.drive_direction][rail.direction]

    data.position.x = data.position.x + f[1] * pos
    data.position.y = data.position.y + f[2] * pos

    return data
end

local nrl = {
    ["straight-rail"] = {
        [1] = {
            [1] = {
                [1] = {type="straight-rail",direction=5,x=2,y=0,drive_direction=0},
                [2] = {type="curved-rail",direction=0,x=3,y=3,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=5,x=0,y=-2,drive_direction=1},
                [0] = {type="curved-rail",direction=3,x=-3,y=-3,drive_direction=0}
            }
        },
        [2] = {
            [1] = {
                [1] = {type="straight-rail",direction=2,x=-2,y=0,drive_direction=1},
                [2] = {type="curved-rail",direction=7,x=-5,y=-1,drive_direction=1},
                [0] = {type="curved-rail",direction=6,x=-5,y=1,drive_direction=1}
            },
            [0] = {
                [1] = {type="straight-rail",direction=2,x=2,y=0,drive_direction=0},
                [2] = {type="curved-rail",direction=3,x=5,y=1,drive_direction=1},
                [0] = {type="curved-rail",direction=2,x=5,y=-1,drive_direction=1}
            }
        },
        [3] = {
            [1] = {
                [1] = {type="straight-rail",direction=7,x=0,y=2,drive_direction=0},
                [2] = {type="curved-rail",direction=2,x=-3,y=3,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=7,x=2,y=0,drive_direction=1},
                [0] = {type="curved-rail",direction=5,x=3,y=-3,drive_direction=0}
            }
        },
        [5] = {
            [1] = {
                [1] = {type="straight-rail",direction=1,x=-2,y=0,drive_direction=0},
                [2] = {type="curved-rail",direction=4,x=-3,y=-3,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=1,x=0,y=2,drive_direction=1},
                [0] = {type="curved-rail",direction=7,x=3,y=3,drive_direction=0}
            }
        },
        [7] = {
            [1] = {
                [1] = {type="straight-rail",direction=3,x=0,y=-2,drive_direction=0},
                [2] = {type="curved-rail",direction=6,x=3,y=-3,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=3,x=-2,y=0,drive_direction=1},
                [0] = {type="curved-rail",direction=1,x=-3,y=3,drive_direction=0}
            }
        },
        [0] = {
            [1] = {
                [1] = {type="straight-rail",direction=0,x=0,y=2,drive_direction=1},
                [2] = {type="curved-rail",direction=5,x=-1,y=5,drive_direction=1},
                [0] = {type="curved-rail",direction=4,x=1,y=5,drive_direction=1}
            },
            [0] = {
                [1] = {type="straight-rail",direction=0,x=0,y=-2,drive_direction=0},
                [2] = {type="curved-rail",direction=1,x=1,y=-5,drive_direction=1},
                [0] = {type="curved-rail",direction=0,x=-1,y=-5,drive_direction=1}
            }
        }
    },
    ["curved-rail"] = {
        [1] = {
            [1] = {
                [1] = {type="straight-rail",direction=7,x=3,y=-3,drive_direction=1},
                [0] = {type="curved-rail",direction=5,x=4,y=-6,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=0,x=-1,y=5,drive_direction=1},
                [2] = {type="curved-rail",direction=5,x=-2,y=8,drive_direction=1},
                [0] = {type="curved-rail",direction=4,x=0,y=8,drive_direction=1}
            }
        },
        [2] = {
            [1] = {
                [1] = {type="straight-rail",direction=3,x=3,y=-3,drive_direction=0},
                [2] = {type="curved-rail",direction=6,x=6,y=-4,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=2,x=-5,y=1,drive_direction=1},
                [2] = {type="curved-rail",direction=7,x=-8,y=0,drive_direction=1},
                [0] = {type="curved-rail",direction=6,x=-8,y=2,drive_direction=1}
            }
        },
        [3] = {
            [1] = {
                [1] = {type="straight-rail",direction=1,x=3,y=3,drive_direction=1},
                [0] = {type="curved-rail",direction=7,x=6,y=4,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=2,x=-5,y=-1,drive_direction=1},
                [2] = {type="curved-rail",direction=7,x=-8,y=-2,drive_direction=1},
                [0] = {type="curved-rail",direction=6,x=-8,y=0,drive_direction=1}
            }
        },
        [4] = {
            [1] = {
                [1] = {type="straight-rail",direction=5,x=3,y=3,drive_direction=0},
                [2] = {type="curved-rail",direction=0,x=4,y=6,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=0,x=-1,y=-5,drive_direction=0},
                [2] = {type="curved-rail",direction=1,x=0,y=-8,drive_direction=1},
                [0] = {type="curved-rail",direction=0,x=-2,y=-8,drive_direction=1}
            }
        },
        [5] = {
            [1] = {
                [1] = {type="straight-rail",direction=3,x=-3,y=3,drive_direction=1},
                [0] = {type="curved-rail",direction=1,x=-4,y=6,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=0,x=1,y=-5,drive_direction=0},
                [2] = {type="curved-rail",direction=1,x=2,y=-8,drive_direction=1},
                [0] = {type="curved-rail",direction=0,x=0,y=-8,drive_direction=1}
            }
        },
        [6] = {
            [1] = {
                [1] = {type="straight-rail",direction=7,x=-3,y=3,drive_direction=0},
                [2] = {type="curved-rail",direction=2,x=-6,y=4,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=2,x=5,y=-1,drive_direction=0},
                [2] = {type="curved-rail",direction=3,x=8,y=0,drive_direction=1},
                [0] = {type="curved-rail",direction=2,x=8,y=-2,drive_direction=1}
            }
        },
        [7] = {
            [1] = {
                [1] = {type="straight-rail",direction=5,x=-3,y=-3,drive_direction=1},
                [0] = {type="curved-rail",direction=3,x=-6,y=-4,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=2,x=5,y=1,drive_direction=0},
                [2] = {type="curved-rail",direction=3,x=8,y=2,drive_direction=1},
                [0] = {type="curved-rail",direction=2,x=8,y=0,drive_direction=1}
            }
        },
        [0] = {
            [1] = {
                [1] = {type="straight-rail",direction=1,x=-3,y=-3,drive_direction=0},
                [2] = {type="curved-rail",direction=4,x=-4,y=-6,drive_direction=0}
            },
            [0] = {
                [1] = {type="straight-rail",direction=0,x=1,y=5,drive_direction=1},
                [2] = {type="curved-rail",direction=5,x=0,y=8,drive_direction=1},
                [0] = {type="curved-rail",direction=4,x=2,y=8,drive_direction=1}
            }
        }
    }
};

local function get_next_rail(rail, conn_dir) 
    local tmp = nrl[rail.type][rail.direction][rail.drive_direction][conn_dir]
    if not tmp then return end

    return {
        type = tmp.type,
        direction = tmp.direction,
        drive_direction = tmp.drive_direction,
        position = {
            x = rail.position.x + tmp.x,
            y = rail.position.y + tmp.y,
        }
    }

end

local function get_rail_behind(rail, behind)
    local data = {
        type = rail.type,
        direction = rail.direction,
        drive_direction = rail.drive_direction,
        position = {
            x = rail.position.x,
            y = rail.position.y,
        }
    }

    for i = 1, behind do
        local br_data = nrl[data.type][data.direction][1 - data.drive_direction][1]
        data.position.x = data.position.x + br_data.x
        data.position.y = data.position.y + br_data.y
        data.direction  = br_data.direction
        data.drive_direction  = 1 - br_data.drive_direction
        data.type  = br_data.type
    end

    return data
end

local function get_rail_in_front(rail, in_front)
    local data = {
        type = rail.type,
        direction = rail.direction,
        drive_direction = rail.drive_direction,
        position = {
            x = rail.position.x,
            y = rail.position.y,
        }
    }

    for i = 1, in_front do
        local fr_data = nrl[data.type][data.direction][data.drive_direction][1]
        data.direction  = fr_data.direction
        data.drive_direction  = fr_data.drive_direction
        data.position.x = data.position.x + fr_data.x
        data.position.y = data.position.y + fr_data.y
        data.type  = fr_data.type
    end

    return data
end

local function travel_rail(rail, steps)
    if steps < 0 then
        return get_rail_behind(rail, -steps)
    elseif steps > 0 then
        return get_rail_in_front(rail, steps)
    else
        return rail
    end
end

local direction_lookup = {
    ["straight-rail"] = {
        [0] = {
            [0] = 0,
            [1] = 7,
            [2] = 2,
            [3] = 1,
            [5] = 3,
            [7] = 5,
        },
        [1] = {
            [0] = 4,
            [1] = 3,
            [2] = 6,
            [3] = 5,
            [5] = 7,
            [7] = 1,
        }
    },
    ["curved-rail"] = {
        [0] = {
            [0] = 4,
            [1] = 4,
            [2] = 6,
            [3] = 6,
            [4] = 0,
            [5] = 0,
            [6] = 2,
            [7] = 2,
        },
        [1] = {
            [0] = 7,
            [1] = 1,
            [2] = 1,
            [3] = 3,
            [4] = 3,
            [5] = 5,
            [6] = 5,
            [7] = 7,
        },
    }
}

local function get_abs_direction(rail) 
    return direction_lookup[rail.type][rail.drive_direction][rail.direction]
end

local function extend_area(area, extend)
    return { { area[1][1] + extend[1][1], area[1][2] + extend[1][2] }, { area[2][1] + extend[2][1] , area[2][2] + extend[2][2] } }
end


local function force_place(player, entity)
    if entity.name == "static-text" then
        return player.surface.create_entity(entity)
    end

    local data = {
        name = entity.name,
        type = entity.type,
        position = {
            x = entity.position.x,
            y = entity.position.y,
        },
        direction = entity.direction,
        force = player.force
    }

    -- TODO
    if not data.name then data.name = data.type end

    local area = { { entity.position.x, entity.position.y }, { entity.position.x, entity.position.y } }
    if entity.type == "straight-rail" then
        if entity.direction % 2 == 1 then
            area = extend_area(area, { { -1.2, -1.2 }, {  1.2,  1.2 } })
        else
            area = extend_area(area, { { -0.8, -0.8 }, {  0.8,  0.8 } })
        end
    elseif entity.type == "curved-rail" then
        -- TODO
        if (entity.direction % 4) < 2 then
            area = extend_area(area, { { -2.0, -4.0 }, {  2.0,  4.0 } })
        else
            area = extend_area(area, { { -4.0, -4.0 }, {  4.0,  2.0 } })
        end
    elseif entity.name == "rail-signal" then
        area = extend_area(area, { { -0.2, -0.2 }, {  0.2,  0.2 } })
    end

    for _, entity in ipairs(player.surface.find_entities_filtered{
                area = extend_area(area, {{ -0.4, -0.4 }, {  0.4,  0.4 }}),
                type = "tree"
            })
    do
       entity.die()
    end


    for _, entity in ipairs(player.surface.find_entities_filtered{
                area = extend_area(area, {{ -1.1, -1.1 }, {  1.1,  1.1 }}),
                name = "stone-rock"
            })
    do
       entity.die()
    end

    for _, entity in ipairs(player.surface.find_entities_filtered{
                area = extend_area(area, {{ -3.2, -2.2 }, {  2.2,  2.2 }}),
                type = "unit-spawner"
            })
    do
       entity.die()
    end

    for _, entity in ipairs(player.surface.find_entities_filtered{
                area = extend_area(area, {{ -0.9, -0.8 }, {  0.9,  0.8 }}),
                type = "turret"
            })
    do
       entity.die()
    end

    if player.surface.can_place_entity(data) then
        return player.surface.create_entity(data)
    else
        -- TODO: move global
        local ignore_type = {}
        local ignore_name = {}
        for _,t in pairs{
            "decorative", "corpse",
            "straight-rail", "curved-rail",
            "locomotive", "cargo-wagon", "unit",
            "resource",
            "smoke", "particle", 
            "tree",
            "flying-text"
        } do ignore_type[t] = true end
        -- for _,t in pairs{"decorative", "straight-rail", "curved-rail", "locomotive", "cargo-wagon", "resource", "smoke", "tree"} do ignore_type[t] = true end

        local water = false
        for x = math.floor(area[1][1]), math.ceil(area[2][1]) do
            for y = math.floor(area[1][2]), math.ceil(area[2][2]) do
                local tile = player.surface.get_tile(x, y).name
                if tile == "water" or tile == "deepwater" then
                    water = true
                end
            end
        end

        if water then
            player.print("We can not drive over water…")
            return
        end

        for _, entity in ipairs(player.surface.find_entities_filtered{
                     area = {
                        {data.position.x - 2.5, data.position.y - 2.5},
                        {data.position.x + 2.5, data.position.y + 2.5}
                    }
                })
        do
            if (not ignore_type[entity.type]) and (not ignore_name[entity.name]) then
                player.surface.create_entity({name = "flying-text", position = entity.position, text = "possible blocking entity: " .. entity.name .. ", (" .. entity.type .. ")", color = {r = 1}})
            end
        end
    end
end

local signal_offset = {
    ["straight-rail"] = {
        [0] = {
            [0] = { direction = 4, x =  1.5, y =  0.5 },
            [1] = { direction = 0, x = -1.5, y = -0.5 },
        },
        [2] = {
            [0] = { direction = 6, x =  0.5, y =  1.5 },
            [1] = { direction = 2, x = -0.5, y = -1.5 },
        },

        [3] = {
            [0] = { direction = 5, x =  1.5, y =  1.5 },
            [1] = { direction = 1, x = -0.5, y = -0.5 },
        },
        [7] = {
            [0] = { direction = 1, x = -1.5, y = -1.5 },
            [1] = { direction = 5, x =  0.5, y =  0.5 },
        },

        [1] = {
            [0] = { direction = 3, x =  1.5, y = -1.5 },
            [1] = { direction = 7, x = -0.5, y =  0.5 },
        },
        [5] = {
            [0] = { direction = 7, x = -1.5, y =  1.5 },
            [1] = { direction = 3, x =  0.5, y = -0.5 },
        },
    },
    ["curved-rail"] = {
        [0] = {
            -- from 0 to 7
            [1] = { direction = 4, x =  2.5, y =  3.5 }, -- start of rail
            [3] = { direction = 3, x = -0.5, y = -3.5 }, -- end   of rail
            -- from 3 to 4
            [0] = { direction = 7, x = -2.5, y = -1.5 }, -- start of rail
            [2] = { direction = 0, x = -0.5, y =  3.5 }, -- end   of rail
        },
        [1] = {
            -- from 0 to 1
            [1] = { direction = 4, x =  0.5, y =  3.5 }, -- start of rail
            [3] = { direction = 5, x =  2.5, y = -1.5 }, -- end   of rail
            -- from 5 to 4
            [0] = { direction = 1, x =  0.5, y = -3.5 }, -- start of rail
            [2] = { direction = 0, x = -2.5, y =  3.5 }, -- end   of rail
        },
        [2] = {
            -- from 2 to 1
            [1] = { direction = 6, x = -3.5, y =  2.5 }, -- start of rail
            [3] = { direction = 5, x =  3.5, y = -0.5 }, -- end   of rail
            -- from 5 to 6
            [0] = { direction = 1, x =  1.5, y = -2.5 }, -- start of rail
            [2] = { direction = 2, x = -3.5, y = -0.5 }, -- end   of rail
        },
        [3] = {
            -- from 2 to 3
            [1] = { direction = 6, x = -3.5, y =  0.5 }, -- start of rail
            [3] = { direction = 7, x =  1.5, y =  2.5 }, -- end   of rail
            -- from 7 to 6
            [0] = { direction = 3, x =  3.5, y =  0.5 }, -- start of rail
            [2] = { direction = 2, x = -3.5, y = -2.5 }, -- end   of rail
        },
        [4] = {
            -- from 4 to 3
            [1] = { direction = 0, x = -2.5, y = -3.5 }, -- start of rail
            [3] = { direction = 7, x =  0.5, y =  3.5 }, -- end   of rail
            -- from 7 to 0
            [0] = { direction = 3, x =  2.5, y =  1.5 }, -- start of rail
            [2] = { direction = 4, x =  0.5, y = -3.5 }, -- end   of rail
        },
        [5] = {
            -- from 4 to 5
            [1] = { direction = 0, x = -0.5, y = -3.5 }, -- start of rail
            [3] = { direction = 1, x = -2.5, y =  1.5 }, -- end   of rail
            -- from 1 to 0
            [0] = { direction = 5, x = -0.5, y =  3.5 }, -- start of rail
            [2] = { direction = 4, x =  2.5, y = -3.5 }, -- end   of rail
        },
        [6] = {
            -- from 6 to 5
            [1] = { direction = 2, x =  3.5, y = -2.5 }, -- start of rail
            [3] = { direction = 1, x = -3.5, y =  0.5 }, -- end   of rail
            -- from 1 to 2
            [0] = { direction = 5, x = -1.5, y =  2.5 }, -- start of rail
            [2] = { direction = 6, x =  3.5, y =  0.5 }, -- end   of rail
        },
        [7] = {
            -- from 6 to 7
            [1] = { direction = 2, x =  3.5, y = -0.5 }, -- start of rail
            [3] = { direction = 3, x = -1.5, y = -2.5 }, -- end   of rail
            -- from 3 to 2
            [0] = { direction = 7, x = -3.5, y = -0.5 }, -- start of rail
            [2] = { direction = 6, x =  3.5, y =  2.5 }, -- end   of rail
        },
    }
}

local function place_signal(player, rail, backwards)
    local drive_direction = backwards and 1 - rail.drive_direction or rail.drive_direction
    local offset = signal_offset[rail.type][rail.direction][drive_direction]
    local signal = {
        name = "rail-signal",
        position = {
            x = rail.position.x + offset.x,
            y = rail.position.y + offset.y,
        },
        direction = offset.direction
    }
    force_place(player, signal)
end

local function get_distance(rail)
    if rail.type == "curved-rail" then
        return 4
    elseif rail.direction % 2 == 1 then
        return 0.8
    else
        return 1
    end
end

script.on_event(defines.events.on_tick, function(event)
    -- TODO foreach player

    -- local player = game.players[event.player_index]
    local stdout = print 
    local player = game.player
    local print = player.print 
    local vehicle = player.vehicle

    if not vehicle then return end

    if not state.active then return end

    local train = state.train
    local is_front = state.is_front

    if is_front and train.speed < 0 then return end
    if (not is_front) and train.speed > 0 then return end

    local rs = player.riding_state

    local real_rail = 
        is_front and train.front_rail or train.back_rail
    local real_drive_direction = 
        is_front and train.rail_direction_from_front_rail or train.rail_direction_from_back_rail
    local conn_dir =  rs.direction -- and where we want to go

    local rail = {
        type = real_rail.type,
        direction = real_rail.direction,
        drive_direction = real_drive_direction,

        position = {
            x = real_rail.position.x,
            y = real_rail.position.y,
        },
    }

    local last_rail =      state.last_rail
    local next_rail =      state.next_rail
    local rail_preview =   state.rail_preview or {}
    local last_conn_dir =  state.last_conn_dir
    local distance =       state.distance
    local add_distance =   state.add_distance
    local main_track = state.main_track

    if real_rail == last_rail then
        if conn_dir == last_conn_dir then
            -- nothing changed
            return
        else
            -- new direction wanted, remove next_rail and previews
            -- if next_rail then next_rail.destroy() end
            for _, rails in ipairs(rail_preview) do 
                if rails then
                    for _, rail in ipairs(rails) do
                        if rail.entity and rail.entity.valid then rail.entity.destroy() end
                    end
                end
            end

            for i = 1, #add_distance do
                add_distance[i] = 0
            end
        end
    elseif real_rail == next_rail then
        -- we moved forward, so we have to decide again
        last_rail = real_rail

        for i, dist in ipairs(add_distance) do
            distance[i] = distance[i] + dist
            add_distance[i] = 0
        end

        -- place signals
        for i, rails in ipairs(rail_preview) do
            local placed_at = 0
            for _, rail in ipairs(rails) do
                if rail.distance - placed_at > 20 then -- TODO
                    place_signal(player, rail)
                    placed_at = rail.distance
                end
            end

            distance[i] = distance[i] - placed_at
        end

        state.behind = state.next_behind

        -- TODO: place pole

    elseif next_rail then
        -- traveled back and started again?

        -- TODO: rescan of signals and poles
        -- next_rail.destroy()

        for _, rails in ipairs(rail_preview) do
            if rails then
                for _, rail in ipairs(rails) do
                    if rail.entity and rail.entity.valid then rail.entity.destroy() end
                end
            end
        end
        
    end

    local tracks = state.tracks

    next_rail = nil
    for i = 1, #tracks do
        rail_preview[i] = {}
    end

    -- check if there is already a rail connected
    local next_rail_exists = real_rail.get_connected_rail({rail_direction = real_drive_direction, rail_connection_direction = conn_dir})

    if next_rail_exists then
        -- TODO maintain
        next_rail = nil

        state.next_rail = next_rail
        state.last_rail = last_rail
        state.rail_preview  = rail_preview 
        return
    end

    -- make a copy
    local behind = {}
    for i,b in ipairs(state.behind) do
        behind[i] = b
    end

    -- check, if we can change direction
    local use_conn_dir = conn_dir
    local next_rail_dir

    local drive_dir = get_abs_direction(rail)

    if (drive_dir % 2 == 0) and conn_dir ~= 1 and #tracks > 0 then
        -- check if we could change direction already
        -- therefore either the lefthand tracks or the righthand tracks must be
        -- far enough behind us, otherwise we go straight

        if conn_dir == 0 then -- go left?
            if tracks[1] < 0 and behind[1] < -tracks[1] then
                use_conn_dir = 1
            end
        elseif conn_dir == 2 then -- go right?
            if tracks[#tracks] > 0 and behind[#tracks] < tracks[#tracks] then
                use_conn_dir = 1
            end
        end
    end

    next_rail = get_next_rail(rail, use_conn_dir)
    -- if we are on a diagonal rail track, we could only go to one side,
    -- otherwise we go straight
    if not next_rail then
        use_conn_dir = 1 -- go straight
        next_rail = get_next_rail(rail, use_conn_dir)
    end

    next_rail.distance = distance[main_track]
    add_distance[main_track] = get_distance(next_rail)
    table.insert(rail_preview[main_track], next_rail)

    if use_conn_dir == 1 then -- just go straight
        -- do we drive diagonal or straight?
        if drive_dir % 2 == 1 then
            -- we dont need to stay behind
            for i, t in ipairs(tracks) do
                if t ~= 0 then
                    local p = get_parallel_rail(next_rail, t)
                    p.distance = distance[i]
                    add_distance[i] = get_distance(p)
                    table.insert(rail_preview[i], p)
                end
            end
        else
            for i, t in ipairs(tracks) do
                if t ~= 0 then
                    if behind[i] < math.abs(t) then
                        behind[i] = behind[i] + 1
                    else
                        local p = get_parallel_rail(next_rail, t)
                        p = get_rail_behind(p, math.abs(t))
                        p.distance = distance[i]
                        add_distance[i] = get_distance(p)
                        table.insert(rail_preview[i], p)
                    end
                end
            end
        end
    else
        -- we change our direction, if we drive diagonal, we can do it
        -- immediatly, otherwise we have to check if the leftmost or rightmost
        -- lane is far enough behind us

        if drive_dir % 2 == 1 then
            -- currently driving diagonal
            for i, t in ipairs(tracks) do
                if t ~= 0 then
                    local p = get_parallel_rail(next_rail, t)
                    p.distance = distance[i]
                    add_distance[i] = get_distance(p)
                    table.insert(rail_preview[i], p)
                end
            end

            -- update the values of staying behind
            if conn_dir == 0 then -- go left
                for i, t in ipairs(tracks) do
                    behind[i] = t
                end
            elseif conn_dir == 2 then
                for i, t in ipairs(tracks) do
                    behind[i] = t * -1
                end
            end
        else
            -- create a tmp rail, which goes straight, which we use to fill the gaps
            local tmp_rail = get_next_rail(rail, 1)

            for i, t in ipairs(tracks) do
                local gap = 0

                if conn_dir == 0 and t > 0 then -- go left, tracks on the right
                    gap = t + behind[i]
                elseif conn_dir == 2 and t < 0 then
                    gap = -t + behind[i]
                end

                if gap > 0 then
                    local pt = get_parallel_rail(tmp_rail, t)
                    pt = travel_rail(pt, -behind[i])

                    -- now we fill the gap
                    for _ = 1, gap do
                        pt.distance = distance[i] + add_distance[i]
                        add_distance[i] = add_distance[i] + get_distance(pt)
                        table.insert(rail_preview[i], pt)
                        pt = get_next_rail(pt, 1)
                    end
                end

                if t ~= 0 then -- not the main track
                    local p = get_parallel_rail(next_rail, t)
                    p.distance = distance[i] + add_distance[i]
                    add_distance[i] = add_distance[i] + get_distance(p)
                    table.insert(rail_preview[i], p)
                end
            end
        end
    end

    -- check, if we can place all rails

    local blocking = false
    for i, rails in ipairs(rail_preview) do
        for _, rail in ipairs(rails) do
            if not blocking then
                rail.entity = force_place(player, rail)
                if not rail.entity then
                    -- check if it alread exists
                    local exists = player.surface.find_entities_filtered{
                        area = {{ rail.position.x, rail.position.y }, { rail.position.x, rail.position.y}},
                        type = rail.type,
                        name = rail.name
                    }
                    if #exists == 0 then
                        blocking = true
                    end
                end
            end
        end
    end

    if blocking then
        for i, rails in ipairs(rail_preview) do
            for _, rail in ipairs(rails) do
                if rail.entity then
                    rail.entity.destroy()
                    rail.entity = nil
                end
            end
        end

        rail_preview = nil
    end

    -- copy state back

    state.last_rail =      real_rail
    state.last_conn_dir =  conn_dir
    state.next_rail =      rail_preview and rail_preview[main_track][1].entity
    state.next_behind =    behind
    state.rail_preview =   rail_preview
    state.distance =       distance
    state.add_distance =   add_distance

end)

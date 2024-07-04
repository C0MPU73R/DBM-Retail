if GetLocale() ~= "zhTW" then return end
if not DBM_COMMON_L then DBM_COMMON_L = {} end

local CL = DBM_COMMON_L

--General
CL.NONE						= "無"
CL.RANDOM					= "隨機"
CL.UNKNOWN					= "未知"--UNKNOWN which is "Unknown" (does u vs U matter?)
CL.NEXT						= "下一次%s"
CL.COOLDOWN					= "%s冷卻"
CL.INCOMING					= "%s 來了"
CL.INTERMISSION				= "中場時間"--No blizz global for this, and will probably be used in most end tier fights with intermission phases
CL.NO_DEBUFF				= "沒有%s"--For use in places like info frame where you put "Not Spellname"
CL.ALLY						= "隊友"--Such as "Move to Ally"
CL.ALLIES					= "隊友"--Such as "Move to Allies"
CL.TANK						= "坦克"--Such as "Move to Tank"
CL.CLEAR					= "清除"
CL.SAFE						= "安全"
CL.NOTSAFE					= "不安全"
CL.SEASONAL					= "季節性"--Used for option headers to label options that apply to seasonal mechanics (Such as season of mastery on classic era)
CL.FULLENERGY				= "滿能量"
--Movements/Places
CL.UP						= "上"
CL.DOWN						= "下"
CL.LEFT						= "左"
CL.RIGHT					= "右"
CL.CENTER					= "中央"
CL.BOTH						= "兩邊"
CL.BEHIND					= "背後"
CL.BACK						= "後"--Back as in back of the room, not back as in body part
CL.SIDE						= "側邊"--Side as in move to the side
CL.TOP						= "上"
CL.BOTTOM					= "下"
CL.MIDDLE					= "中"
CL.FRONT					= "前"
CL.EAST						= "東"
CL.WEST						= "西"
CL.NORTH					= "北"
CL.SOUTH					= "南"
CL.NORTHEAST				= "東北"
CL.SOUTHEAST				= "東南"
CL.SOUTHWEST				= "西南"
CL.NORTHWEST				= "西北"
CL.SHIELD					= "護盾"--Usually auto localized but kept around in case it needs to be used in a place that's not auto localized such as MoveTo or Use alert
CL.PILLAR					= "柱子"
CL.SHELTER					= "掩蔽"
CL.EDGE						= "房間邊緣"
CL.FAR_AWAY					= "遠離"
CL.PIT						= "坑洞"--Pit, as in hole in ground
CL.TOTEM					= "圖騰"
CL.TOTEMS					= "圖騰"
CL.HORIZONTAL				= "水平"
CL.VERTICAL					= "垂直"
--Mechanics
CL.BOMB						= "炸彈"
CL.BOMBS					= "炸彈"
CL.ORB						= "球"
CL.ORBS						= "球"
CL.RING						= "環"
CL.RINGS					= "環"
CL.CHEST					= "獎勵箱"--As in Treasure 'Chest'. Not Chest as in body part.
CL.ADD						= "小怪"--A fight Add as in "boss spawned extra adds"
CL.ADDS						= "小怪"
CL.ADDCOUNT					= "小怪 %s"
CL.BIG_ADD					= "大怪"
CL.BOSS						= "首領"
CL.ENEMIES					= "敵人"
CL.BREAK_LOS				= "卡視角"
CL.RESTORE_LOS				= "恢復/保持視角"
CL.BOSSTOGETHER				= "首領靠近"
CL.BOSSAPART				= "首領分開"
CL.MINDCONTROL				= "心控"
CL.TANKCOMBO				= "坦克連擊"
CL.AOEDAMAGE				= "AOE傷害"
CL.GROUPSOAK				= "隊伍分傷"
CL.GROUPSOAKS				= "隊伍分傷"
CL.HEALABSORB				= "治療吸收"
CL.HEALABSORBS				= "治療吸收"
CL.DODGES					= "躲避"
CL.POOL						= "圈"
CL.POOLS					= "圈"
CL.DEBUFFS					= "減益"
CL.DISPELS					= "驅散"
CL.PUSHBACK					= "推後"
CL.FRONTAL					= "正面攻擊"
CL.RUNAWAY					= "快躲開"
CL.SPREAD					= "分散"
CL.SPREADS					= "分散"
CL.LASER					= "雷射"
CL.LASERS					= "雷射"
CL.RIFT						= "裂隙"--Often has auto localized alternatives, but still translated for BW aura matching when needed
CL.RIFTS					= "裂隙"--Often has auto localized alternatives, but still translated for BW aura matching when needed
CL.TRAPS					= "陷阱"--Doesn't have a direct auto localize so has to be manually localized, unlike non plural version
CL.ROOTS					= "定身"
CL.MARK						= "標記"--As in short text for all the encounter mechanics that start or end in "Mark"
CL.MARKS					= "標記"--Plural of above
CL.CURSE					= "詛咒"
CL.CURSES					= "詛咒"
CL.SWIRLS					= "迴旋"--Plural of Swirl

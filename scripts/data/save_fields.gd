extends RefCounted
## 存档字段表：GameState 里每个要存档的变量在这里登记一次。
## 保存 / 读取 / 重置存档都按这张表来，新加字段只需要加一行（读取后的额外校验写在 GameState._sanitize_loaded）。
##   名字: [默认值, 重置存档时是否保留]
## 读档时按默认值的类型转换（int / float / bool / String / Array / Dictionary）；没有这个字段的老存档用默认值。

const FIELDS := {
	# 摩尔豆和背包
	"beans": [100, false],
	"inventory": [{}, false],
	"selected_seed": ["carrot", false],
	# 外观（名字、毛色在重置存档后保留）
	"player_name": ["", true],
	"body_color": ["", true],
	"hat": ["none", false],
	"title": ["", false],
	"owned_hats": [["none"], false],
	# 工具
	"rod_level": [0, false],
	"has_sprinkler": [false, false],
	"has_greenhouse": [false, false],
	# 拉姆
	"lahm_acc": ["none", false],
	"owned_lahm_accs": [["none"], false],
	"lahm_hunger": [80.0, false],
	"lahm_exp": [0, false],
	"lahm_level": [1, false],
	"lahm_hide_day": [-1, false],
	# 等级
	"player_exp": [0, false],
	"player_level": [1, false],
	# 时间
	"day": [1, false],
	"minutes": [480.0, false],
	"leaf_day": [-1, false],
	"lucky_day": [-1, false],
	# 任务、引导、剧情、每周挑战
	"quest": [{}, false],
	"quests_done": [0, false],
	"help_today": [0, false],
	"tutorial_step": [-1, false],
	"story_step": [-2, false],
	"story_count": [0, false],
	"weekly_week": [-1, false],
	"weekly_base": [0, false],
	"weekly_claimed": [false, false],
	# 小游戏、钓鱼大赛
	"best_catch": [0, false],
	"contest_day": [-1, false],
	"contest_count": [0, false],
	"catch_day": [-1, false],
	"catch_plays": [0, false],
	# 图鉴、统计、成就
	"collection": [{}, false],
	"fish_records": [{}, false],
	"day_log": [{}, false],
	"stats": [{}, false],
	"achievements": [[], false],
	# 签到（按现实日期，重置后保留，避免同一天重复领）
	"last_signin": ["", true],
	"signin_streak": [0, true],
	# 设置（重置后保留）
	"music_volume": [0.6, true],
	"sfx_volume": [0.8, true],
	"ui_scale": [1.0, true],
	# 农场、小院、留言板、信箱、NPC
	"plots": [{}, false],
	"home": [[], false],
	"board": [[], false],
	"mail": [[], false],
	"npc_affinity": [{}, false],
	"npc_gift_day": [{}, false],
}

## 值必须是整数的字典（JSON 读回来都是浮点数）
const INT_DICTS := ["inventory", "collection", "fish_records", "day_log", "stats", "npc_affinity", "npc_gift_day"]


## 把存档里的值转换成和默认值一样的类型；类型不对就用默认值
static func coerce(field: String, v, def):
	if v == null:
		return def.duplicate(true) if def is Array or def is Dictionary else def
	match typeof(def):
		TYPE_INT:
			return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL] else def
		TYPE_FLOAT:
			return float(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else def
		TYPE_BOOL:
			return bool(v)
		TYPE_STRING:
			return str(v)
		TYPE_ARRAY:
			return v if v is Array else def.duplicate(true)
		TYPE_DICTIONARY:
			if not v is Dictionary:
				return def.duplicate(true)
			if field in INT_DICTS:
				var out := {}
				for k in v:
					out[str(k)] = int(v[k])
				return out
			return v
	return v

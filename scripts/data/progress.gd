extends RefCounted
## 成长与目标数据：成就、新手引导、国王的每周挑战。
## 只放常量；GameState 里有同名的常量指向这里，其他代码继续用 GameState.XXX。

const ACHIEVEMENTS := [
	{"id": "first_harvest", "name": "第一次收获", "desc": "收获 1 个作物", "stat": "harvest_total", "target": 1, "reward": 20},
	{"id": "farmer", "name": "勤劳的农夫", "desc": "累计收获 50 个作物", "stat": "harvest_total", "target": 50, "reward": 150},
	{"id": "all_crops", "name": "作物大全", "desc": "每种作物都收获过", "stat": "crop_kinds", "target": 6, "reward": 120},
	{"id": "first_fish", "name": "初次垂钓", "desc": "钓到 1 条鱼", "stat": "fish_total", "target": 1, "reward": 20},
	{"id": "angler", "name": "钓鱼达人", "desc": "累计钓到 30 条鱼", "stat": "fish_total", "target": 30, "reward": 150},
	{"id": "gold_fish", "name": "金光闪闪", "desc": "钓到一条金鱼", "stat": "c:gold_fish", "target": 1, "reward": 100},
	{"id": "all_fish", "name": "湖中宝藏", "desc": "集齐湖里能钓到的所有东西（包括四季限定的鱼）", "stat": "fish_kinds", "target": 8, "reward": 120},
	{"id": "quests", "name": "乐乐的好帮手", "desc": "完成 10 个乐乐的任务", "stat": "quests_done", "target": 10, "reward": 200},
	{"id": "rich", "name": "小富翁", "desc": "同时拥有 1000 摩尔豆", "stat": "beans", "target": 1000, "reward": 100},
	{"id": "visitor", "name": "串门达人", "desc": "去好友家串门 1 次", "stat": "visits", "target": 1, "reward": 30},
	{"id": "helper", "name": "热心邻居", "desc": "去好友农场帮忙 10 次", "stat": "help_total", "target": 10, "reward": 100},
	{"id": "fashion", "name": "时尚达人", "desc": "集齐所有帽子", "stat": "hats", "target": 5, "reward": 200},
	{"id": "lahm_friend", "name": "拉姆的好朋友", "desc": "把拉姆培养到 5 级", "stat": "lahm_level", "target": 5, "reward": 300},
	{"id": "level10", "name": "小镇达人", "desc": "升到 10 级", "stat": "player_level", "target": 10, "reward": 500},
	{"id": "popular", "name": "小镇人气王", "desc": "和一位 NPC 成为好朋友（好感 100）", "stat": "max_affinity", "target": 100, "reward": 200},
	{"id": "catcher", "name": "接果子高手", "desc": "在接果子小游戏里拿到 40 分", "stat": "best_catch", "target": 40, "reward": 150},
	{"id": "lucky", "name": "幸运儿", "desc": "钓鱼时钓到一个宝箱", "stat": "treasures", "target": 1, "reward": 100},
	{"id": "stargazer", "name": "追星的小摩尔", "desc": "对着流星许 5 个愿望", "stat": "wishes", "target": 5, "reward": 120},
	{"id": "story", "name": "城堡的秘密", "desc": "完成主线剧情", "stat": "story_done", "target": 1, "reward": 200},
	{"id": "dancer", "name": "舞林高手", "desc": "和好友一起合拍地做 5 次表情", "stat": "dances", "target": 5, "reward": 150},
	{"id": "chef", "name": "小厨神", "desc": "累计做 20 道菜", "stat": "cook_total", "target": 20, "reward": 200},
	{"id": "giant", "name": "巨无霸", "desc": "收获一个巨型作物", "stat": "giants", "target": 1, "reward": 120},
	{"id": "hide_seek", "name": "捉迷藏冠军", "desc": "和拉姆玩捉迷藏，找到它 3 次", "stat": "hide_found", "target": 3, "reward": 100},
	{"id": "fireflies", "name": "夏夜萤火", "desc": "夏天的夜里抓 10 只萤火虫", "stat": "fireflies", "target": 10, "reward": 120},
	{"id": "clover", "name": "幸运四叶草", "desc": "春天里找到 3 棵四叶草", "stat": "clovers", "target": 3, "reward": 120},
	{"id": "all_dishes", "name": "美食家", "desc": "每道菜都做过", "stat": "dish_kinds", "target": 7, "reward": 250},
]

const TUTORIAL := [
	{"text": "点击农场（右下）里的空地，种下一颗萝卜", "event": "plant", "target": "farm"},
	{"text": "再点一下刚种下的萝卜，给它浇水", "event": "water", "target": "farm"},
	{"text": "去钓鱼湖（左下）点击湖面，钓一条鱼", "event": "fish", "target": "pond"},
	{"text": "去摩尔百货找店长豆豆，买一颗种子", "event": "buy_seed", "target": "shop"},
	{"text": "去广场找乐乐聊聊，她会给你任务", "event": "talk_lele", "target": "lele"},
	{"text": "点击你的拉姆，喂喂它或者摸摸它", "event": "lahm", "target": "lahm"},
]

const WEEKLY := [
	{"stat": "harvest_total", "target": 20, "text": "收获 20 个作物"},
	{"stat": "fish_total", "target": 10, "text": "钓到 10 条鱼"},
	{"stat": "cook_total", "target": 5, "text": "做 5 道菜"},
	{"stat": "quests_done", "target": 3, "text": "完成 3 个乐乐的任务"},
]

extends RefCounted
## 物品数据：作物、鱼、帽子、家具、料理、拉姆饰品、鱼竿、旅行商人的货。
## 只放常量；GameState 里有同名的常量指向这里，其他代码继续用 GameState.XXX。

const CROPS := {
	"carrot": {"name": "萝卜", "seed_price": 5, "sell": 12, "grow_time": 25.0, "level": 1, "exp": 2, "seasons": [0, 2], "color": Color(1.0, 0.55, 0.15)},
	"strawberry": {"name": "草莓", "seed_price": 12, "sell": 30, "grow_time": 45.0, "level": 1, "exp": 3, "seasons": [0], "color": Color(0.95, 0.2, 0.3)},
	"corn": {"name": "玉米", "seed_price": 18, "sell": 45, "grow_time": 60.0, "level": 2, "exp": 4, "seasons": [1], "color": Color(1.0, 0.85, 0.3)},
	"pumpkin": {"name": "南瓜", "seed_price": 25, "sell": 70, "grow_time": 80.0, "level": 3, "exp": 6, "seasons": [2], "color": Color(1.0, 0.6, 0.1)},
	"sunflower": {"name": "向日葵", "seed_price": 40, "sell": 120, "grow_time": 120.0, "level": 5, "exp": 9, "seasons": [1], "color": Color(1.0, 0.85, 0.1)},
	"watermelon": {"name": "西瓜", "seed_price": 60, "sell": 180, "grow_time": 150.0, "level": 7, "exp": 14, "seasons": [1], "color": Color(0.3, 0.68, 0.3)},
}

const FISH := {
	"small_fish": {"name": "小鱼", "sell": 8, "weight": 50, "color": Color(0.55, 0.72, 0.88), "size": [8, 20]},
	"big_fish": {"name": "大鱼", "sell": 22, "weight": 28, "color": Color(0.3, 0.5, 0.82), "size": [30, 62]},
	"gold_fish": {"name": "金鱼", "sell": 60, "weight": 8, "color": Color(1.0, 0.75, 0.15), "size": [14, 30]},
	"boot": {"name": "破靴子", "sell": 1, "weight": 14, "color": Color(0.5, 0.35, 0.25)},
	# 季节限定的鱼：只在对应季节能钓到
	"sakura_fish": {"name": "樱花鱼", "sell": 32, "weight": 14, "season": 0, "color": Color(1.0, 0.65, 0.78), "size": [18, 34]},
	"tropical_fish": {"name": "热带鱼", "sell": 36, "weight": 14, "season": 1, "color": Color(0.2, 0.8, 0.75), "size": [12, 26]},
	"maple_carp": {"name": "枫叶鲤", "sell": 40, "weight": 14, "season": 2, "color": Color(0.9, 0.4, 0.15), "size": [30, 56]},
	"ice_fish": {"name": "冰鱼", "sell": 45, "weight": 14, "season": 3, "color": Color(0.75, 0.9, 1.0), "size": [18, 34]},
}

const HATS := {
	"none": {"name": "不戴帽子", "price": 0},
	"red_cap": {"name": "红色小帽", "price": 80},
	"straw": {"name": "草帽", "price": 120},
	"flower": {"name": "小花发卡", "price": 150},
	"crown": {"name": "小王冠", "price": 500, "level": 6},
	"wizard": {"name": "魔法帽", "price": 800, "level": 8},
	"star_pin": {"name": "星星发卡", "price": 0, "level": 1, "shop": false},  # 主线剧情奖励
	"bunny": {"name": "兔耳朵", "price": 0, "level": 1, "shop": false},  # 扭蛋限定
	"chick": {"name": "小黄鸡", "price": 0, "level": 1, "shop": false},  # 扭蛋限定
}

const FURNITURE := {
	"pot": {"name": "小花盆", "price": 30, "level": 1},
	"mailbox": {"name": "邮筒", "price": 40, "level": 1},
	"table": {"name": "下午茶桌", "price": 60, "level": 1},
	"bench": {"name": "长椅", "price": 70, "level": 2},
	"lantern": {"name": "小灯笼", "price": 80, "level": 2},
	"scarecrow": {"name": "稻草人", "price": 100, "level": 3},
	"campfire": {"name": "篝火", "price": 120, "level": 4},
	"swing": {"name": "秋千", "price": 160, "level": 5},
	"lahm_house": {"name": "拉姆小屋", "price": 220, "level": 6},
	"windmill": {"name": "风车", "price": 320, "level": 8},
	# 季节限定：只在对应季节的商店里卖
	"sakura_bonsai": {"name": "樱花盆景", "price": 150, "level": 2, "season": 0},
	"melon_chair": {"name": "西瓜躺椅", "price": 150, "level": 2, "season": 1},
	"pumpkin_lamp": {"name": "南瓜灯", "price": 150, "level": 2, "season": 2},
	"snowman": {"name": "雪人", "price": 150, "level": 2, "season": 3},
	"trophy": {"name": "金奖杯", "price": 0, "level": 1, "shop": false},  # 国王的每周挑战奖励，商店不卖
	"telescope": {"name": "望远镜", "price": 0, "level": 1, "shop": false},  # 旅行商人卖的
	"firefly_jar": {"name": "萤火虫灯", "price": 0, "level": 1, "shop": false},  # 累计抓 10 只萤火虫的奖励
}

const DISHES := {
	"carrot_soup": {"name": "萝卜汤", "needs": {"carrot": 2}, "sell": 35, "exp": 4, "color": Color(1.0, 0.6, 0.25)},
	"fish_soup": {"name": "鲜鱼汤", "needs": {"big_fish": 1, "carrot": 1}, "sell": 48, "exp": 5, "color": Color(0.95, 0.92, 0.82)},
	"strawberry_cake": {"name": "草莓蛋糕", "needs": {"strawberry": 2, "corn": 1}, "sell": 140, "exp": 8, "color": Color(1.0, 0.55, 0.65)},
	"grilled_corn": {"name": "烤玉米", "needs": {"corn": 2}, "sell": 110, "exp": 6, "color": Color(0.95, 0.75, 0.25)},
	"pumpkin_pie": {"name": "南瓜派", "needs": {"pumpkin": 1, "strawberry": 1}, "sell": 130, "exp": 8, "color": Color(0.95, 0.55, 0.15)},
	"watermelon_smoothie": {"name": "西瓜冰沙", "needs": {"watermelon": 1, "strawberry": 1}, "sell": 250, "exp": 12, "color": Color(1.0, 0.4, 0.45)},
	"lahm_meal": {"name": "拉姆特制饭", "needs": {"carrot": 1, "small_fish": 1}, "sell": 30, "exp": 5, "color": Color(1.0, 0.75, 0.85)},
}

const LAHM_ACCS := {
	"none": {"name": "不戴饰品", "price": 0},
	"bow": {"name": "蝴蝶结", "price": 60},
	"glasses": {"name": "小眼镜", "price": 90},
	"scarf": {"name": "小围巾", "price": 120},
}

const RODS := [
	{"name": "普通鱼竿", "price": 0, "level": 1},
	{"name": "好鱼竿", "price": 300, "level": 3},
	{"name": "金鱼竿", "price": 800, "level": 6},
]

## 每周第 6、7 天（周末）的白天，旅行商人阿布会在湖边摆摊
const MERCHANT_STOCK := [
	{"id": "mystery_seed", "n": 1, "price": 60, "desc": "随机 2 颗种子，可能是没解锁的作物"},
	{"id": "furn_telescope", "n": 1, "price": 400, "desc": "远方运来的铜望远镜，摆在小院里很神气"},
	{"id": "fertilizer", "n": 5, "price": 100, "desc": "肥料 5 袋装，比商店便宜"},
	{"id": "lahm_fruit", "n": 10, "price": 120, "desc": "拉姆果 10 个装，比商店便宜"},
]

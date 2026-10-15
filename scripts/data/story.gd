extends RefCounted
## 小镇居民与剧情数据：NPC 喜好和回礼、信件、主线剧情「城堡的秘密」。
## 只放常量；GameState 里有同名的常量指向这里，其他代码继续用 GameState.XXX。

const NPC_INFO := {
	"乐乐": {"birthday": 3, "likes": ["strawberry", "sunflower", "strawberry_cake"], "rewards": {20: ["lahm_fruit", 3], 50: ["beans", 100], 100: ["furn_lahm_house", 1]}},
	"店长豆豆": {"birthday": 9, "likes": ["gold_fish", "watermelon", "carrot_soup"], "rewards": {20: ["seed_corn", 3], 50: ["beans", 150], 100: ["furn_lantern", 2]}},
	"小黄": {"birthday": 13, "likes": ["corn", "carrot", "grilled_corn"], "rewards": {20: ["seed_strawberry", 3], 50: ["furn_bench", 1], 100: ["beans", 200]}},
	"嘟嘟": {"birthday": 17, "likes": ["big_fish", "small_fish", "fish_soup", "ice_fish"], "rewards": {20: ["lahm_fruit", 2], 50: ["furn_campfire", 1], 100: ["beans", 250]}},
	"米米": {"birthday": 23, "likes": ["pumpkin", "strawberry", "pumpkin_pie"], "rewards": {20: ["seed_pumpkin", 3], 50: ["furn_pot", 2], 100: ["furn_swing", 1]}},
	"阿呆": {"birthday": 26, "likes": ["watermelon", "gold_fish", "watermelon_smoothie"], "rewards": {20: ["beans", 50], 50: ["furn_scarecrow", 1], 100: ["furn_windmill", 1]}},
}

const MAIL_LINES := {
	"乐乐": ["最近农场种得怎么样？给你寄了点小东西~", "谢谢你一直帮我做任务！这是一点心意。"],
	"店长豆豆": ["摩尔百货感谢你的光临！附上一点小礼物。", "下次来店里，记得看看今天的特价哦~"],
	"小黄": ["我在广场上看到你啦！送你点东西~", "一起去钓鱼吧！先送你点好东西。"],
	"嘟嘟": ["今天湖边的风好舒服，给你寄了点东西。", "钓鱼的诀窍是耐心哦！附赠小礼物~"],
	"米米": ["我的草莓熟了，分你一点！", "农场的害虫被你抓走了好多，谢谢你！"],
	"阿呆": ["城堡守卫阿呆来信！附上一点心意。", "嘿嘿，猜猜我给你寄了什么？"],
}

const STORY := [
	{"text": "去城堡附近找守卫阿呆聊聊", "event": "talk_阿呆", "target": "adai",
		"beat": ["阿呆", "嘿嘿，告诉你一个秘密：国王最近总是愁眉苦脸的，好像丢了什么重要的东西……听说他前几天在钓鱼湖边散过步。"]},
	{"text": "在钓鱼湖钓 3 次鱼，找找国王丢的东西", "event": "fish", "count": 3, "target": "pond",
		"beat": ["钓鱼湖", "鱼线猛地一沉——钓上来一把生锈的旧钥匙！上面刻着城堡的徽章。"]},
	{"text": "把旧钥匙交给城堡大厅里的摩尔国王", "event": "talk_摩尔国王", "target": "castle",
		"beat": ["摩尔国王", "这是……城堡地下室的钥匙！太谢谢你了。不过我饿得讲不动故事了，能给我做一道菜吗？"]},
	{"text": "去广场的小厨房做一道菜", "event": "cook", "target": "stove",
		"beat": ["小厨房", "香喷喷的菜做好了，快趁热送去给国王吧！"]},
	{"text": "把做好的菜送给摩尔国王", "event": "talk_摩尔国王", "target": "castle",
		"beat": ["摩尔国王", "真好吃！那我告诉你吧：很久以前，守护小镇的星星落进了钓鱼湖。只有在夜里，湖面才会映出它的光……晚上 9 点以后去湖边看看吧。"]},
	{"text": "晚上 9 点以后去钓鱼湖边看看", "event": "night_pond", "target": "pond",
		"beat": ["钓鱼湖", "湖面闪闪发光，一颗小星星从水里慢慢浮了上来，轻轻落在你的头上——变成了一枚星星发卡！"]},
]

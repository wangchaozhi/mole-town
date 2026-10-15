#!/bin/bash
# 提交前检查：静态检查 + 冒烟测试（加 --soak 再跑一分钟浸泡测试）。任何一项失败都以非 0 退出。
#   本地：GODOT=/path/to/godot tools/check.sh [--soak]
#   CI：.github/workflows/ci.yml 用同一个脚本
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
# 测试的日志写到临时目录，不占用游戏自己的日志目录（玩家游玩的日志才不会被测试挤掉）
LOGDIR=$(mktemp -d)
LOGARG=(--log-file "$LOGDIR/godot.log")
fail=0

# 1. 字符串里混进了真换行（引号数量为奇数的行）——GDScript 不报错，但显示会出问题
bad=$(for f in scripts/*/*.gd tests/*.gd; do
	awk -v F="$f" '{ n = gsub(/"/, "\""); if (n % 2 == 1 && $0 !~ /^[ \t]*#/ && $0 !~ /"""/) print F ":" NR }' "$f"
done)
if [ -n "$bad" ]; then echo "✗ 字符串里有真换行：$bad"; fail=1; fi

# 2. 冒烟测试里重复声明的局部变量（会导致整个测试脚本解析失败）
dup=$(sed -n 's/^\tvar \([a-zA-Z0-9_]*\).*/\1/p' tests/smoke_test.gd | sort | uniq -d)
if [ -n "$dup" ]; then echo "✗ smoke_test.gd 里重复声明的变量：$dup"; fail=1; fi

# 3. 引用了不存在的脚本路径
for p in $(grep -rhoE 'res://scripts/[a-z_/]+\.gd' scripts tests main.tscn project.godot | sort -u); do
	[ -f "${p#res://}" ] || { echo "✗ 找不到 $p"; fail=1; }
done
[ $fail -ne 0 ] && exit 1

# 4. 导入资源 + 冒烟测试；日志里有脚本错误也算失败（Godot 遇到解析错误时退出码不一定非 0）
"$GODOT" "${LOGARG[@]}" --headless --path . --import > /dev/null 2>&1
log=$(mktemp)
timeout 120 "$GODOT" "${LOGARG[@]}" --headless --path . res://tests/smoke_test.tscn -- --profile=smoke > "$log" 2>&1
rc=$?
grep -E "✗|====" "$log"
if [ $rc -ne 0 ] || grep -q "SCRIPT ERROR" "$log"; then
	echo "✗ 冒烟测试失败（exit=$rc）"
	grep -A3 "SCRIPT ERROR" "$log" | head -30
	exit 1
fi

# 5. 可选：浸泡测试（机器人随机玩 1 分钟）
if [ "${1:-}" = "--soak" ]; then
	timeout 180 "$GODOT" "${LOGARG[@]}" --headless --path . res://tests/soak_test.tscn -- --profile=soak > "$log" 2>&1
	grep "浸泡测试结束" "$log"
	if grep -q "SCRIPT ERROR" "$log"; then
		echo "✗ 浸泡测试出现脚本错误"
		grep -A3 "SCRIPT ERROR" "$log" | head -30
		exit 1
	fi
fi
echo "✓ 全部检查通过"

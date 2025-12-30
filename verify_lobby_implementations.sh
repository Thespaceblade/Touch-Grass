#!/bin/bash
# Verify Lobby Implementations
# This script checks that all lobby views have the necessary components

BASE_DIR="Touch-Grass/Touch-Grass/Views"
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================================"
echo "Lobby Implementation Verification"
echo "============================================================"
echo ""

check() {
    local file=$1
    local pattern=$2
    local desc=$3
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $desc"
        return 0
    else
        echo -e "${RED}✗${NC} $desc"
        return 1
    fi
}

FAILED=0

# CTF Lobby
echo -e "${BLUE}CTF Lobby${NC}"
CTF="$BASE_DIR/CaptureTheFlag/CTFLobbyView.swift"
check "$CTF" "sessionInfoCard" "Session info card" || ((FAILED++))
check "$CTF" "playerListCard" "Player list card" || ((FAILED++))
check "$CTF" "showTeamManagement" "Team management state" || ((FAILED++))
check "$CTF" "CTFBubbleSettingsView" "CTF bubble settings" || ((FAILED++))
check "$CTF" "CTFTeamManagementView" "CTF team management" || ((FAILED++))
check "$CTF" "Configure Game" "Configure game button" || ((FAILED++))
check "$CTF" "Manage Teams" "Manage teams button" || ((FAILED++))
check "$CTF" "Begin Game" "Begin game button" || ((FAILED++))
check "$CTF" "viewModel.gameService.session?.bubble" "Dynamic bubble check" || ((FAILED++))
check "$CTF" "teamAPlayers\|\.teamA" "Team A filtering" || ((FAILED++))
check "$CTF" "teamBPlayers\|\.teamB" "Team B filtering" || ((FAILED++))
echo ""

# Manhunt Lobby
echo -e "${BLUE}Manhunt Lobby${NC}"
MH="$BASE_DIR/Manhunt/ManhuntLobbyView.swift"
check "$MH" "sessionInfoCard" "Session info card" || ((FAILED++))
check "$MH" "playerListCard" "Player list card" || ((FAILED++))
check "$MH" "showHunterManagement" "Hunter management state" || ((FAILED++))
check "$MH" "ManhuntBubbleSettingsView" "Manhunt bubble settings" || ((FAILED++))
check "$MH" "ManhuntHunterManagementView" "Manhunt hunter management" || ((FAILED++))
check "$MH" "Configure Game" "Configure game button" || ((FAILED++))
check "$MH" "Manage Hunters" "Manage hunters button" || ((FAILED++))
check "$MH" "Begin Game" "Begin game button" || ((FAILED++))
check "$MH" "viewModel.gameService.session?.bubble" "Dynamic bubble check" || ((FAILED++))
check "$MH" "hunters\|\.hunter" "Hunter filtering" || ((FAILED++))
check "$MH" "hiders\|\.hider" "Hider filtering" || ((FAILED++))
echo ""

# ZombieTag Lobby
echo -e "${BLUE}ZombieTag Lobby${NC}"
ZT="$BASE_DIR/ZombieTag/ZombieTagLobbyView.swift"
check "$ZT" "sessionInfoCard" "Session info card" || ((FAILED++))
check "$ZT" "playerListCard" "Player list card" || ((FAILED++))
check "$ZT" "showZombieManagement" "Zombie management state" || ((FAILED++))
check "$ZT" "ZombieTagBubbleSettingsView" "ZombieTag bubble settings" || ((FAILED++))
check "$ZT" "ZombieTagRoleManagementView" "ZombieTag role management" || ((FAILED++))
check "$ZT" "Configure Game" "Configure game button" || ((FAILED++))
check "$ZT" "Manage Zombies" "Manage zombies button" || ((FAILED++))
check "$ZT" "Begin Game" "Begin game button" || ((FAILED++))
check "$ZT" "viewModel.gameService.session?.bubble" "Dynamic bubble check" || ((FAILED++))
check "$ZT" "zombies\|\.zombie" "Zombie filtering" || ((FAILED++))
check "$ZT" "humans\|\.human" "Human filtering" || ((FAILED++))
echo ""

echo "============================================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All components verified!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED checks failed${NC}"
    exit 1
fi




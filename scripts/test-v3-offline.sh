#!/bin/zsh
# 在 macOS 上执行真实会话实现的脱敏 URLProtocol 测试，不启动模拟器、不访问服务端。
set -eu
cd "${0:A:h:h}"
binary="$(mktemp -t shishanyouni-v3-tests)"
trap 'rm -f "$binary"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -D V3_OFFLINE_TESTS \
  shishanyouni/Account/ShishanyouniBackend/Models/ShishanyouniV3Models.swift \
  shishanyouni/Account/ShishanyouniBackend/API/ShishanyouniAPI.swift \
  shishanyouni/Account/ShishanyouniBackend/API/ShishanyouniV3API.swift \
  shishanyouni/Account/ShishanyouniBackend/Service/ShishanyouniV3CredentialStore.swift \
  shishanyouni/Account/ShishanyouniBackend/Service/ShishanyouniV3Session.swift \
  shishanyouni/Core/Networking/NetworkService.swift \
  shishanyouni/Core/Storage/KeychainHelper.swift \
  shishanyouni/Curriculum/Models/CurriculumAPIModels.swift \
  shishanyouni/Curriculum/Models/CurriculumModels.swift \
  shishanyouni/Curriculum/Service/CurriculumWeekParser.swift \
  shishanyouni/Curriculum/importCurriculum/API/ShishanyouniCurriculumAPI.swift \
  shishanyouni/Curriculum/importCurriculum/Service/ShishanyouniCurriculumImporter.swift \
  shishanyouniTests/ShishanyouniV3Tests.swift -o "$binary"
"$binary"

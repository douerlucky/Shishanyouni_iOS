import SwiftUI

// MARK: - 按性别和年级计算体测单项分数

struct ProjectStandard
{
    static func getGrade(from score: Double) -> String
    {
        switch score
        {
        case 90 ... 100: return "优秀"
        case 80 ..< 90: return "良好"
        case 60 ..< 80: return "及格"
        default: return "不及格"
        }
    }

    static func score(for project: String, value: Double, gender: String, gradeLevel: String) -> (Double, String)
    {
        let cur_gradeLevel = gradeLevel.suffix(1)
        var finalScore: Double = 0
        let isJuniorSenior = (cur_gradeLevel == "三" || cur_gradeLevel == "四" || cur_gradeLevel == "五")

        if gender == "男"
        {
            switch project
            {
            case "肺活量":
                if !isJuniorSenior
                { // 大一二
                    if value >= 5040 { finalScore = 100 } else if value >= 4920 { finalScore = 95 } else if value >= 4800 { finalScore = 90 } else if value >= 4550 { finalScore = 85 } else if value >= 4300 { finalScore = 80 } else if value >= 4180 { finalScore = 78 } else if value >= 4060 { finalScore = 76 } else if value >= 3940 { finalScore = 74 } else if value >= 3820 { finalScore = 72 } else if value >= 3700 { finalScore = 70 } else if value >= 3580 { finalScore = 68 } else if value >= 3460 { finalScore = 66 } else if value >= 3340 { finalScore = 64 } else if value >= 3220 { finalScore = 62 } else if value >= 3100 { finalScore = 60 } else if value >= 2940 { finalScore = 50 } else if value >= 2780 { finalScore = 40 } else if value >= 2620 { finalScore = 30 } else if value >= 2460 { finalScore = 20 } else if value >= 2300 { finalScore = 10 }
                }
                else
                { // 大三四
                    if value >= 5140 { finalScore = 100 } else if value >= 5020 { finalScore = 95 } else if value >= 4900 { finalScore = 90 } else if value >= 4650 { finalScore = 85 } else if value >= 4400 { finalScore = 80 } else if value >= 4280 { finalScore = 78 } else if value >= 4160 { finalScore = 76 } else if value >= 4040 { finalScore = 74 } else if value >= 3920 { finalScore = 72 } else if value >= 3800 { finalScore = 70 } else if value >= 3680 { finalScore = 68 } else if value >= 3560 { finalScore = 66 } else if value >= 3440 { finalScore = 64 } else if value >= 3320 { finalScore = 62 } else if value >= 3200 { finalScore = 60 } else if value >= 3030 { finalScore = 50 } else if value >= 2860 { finalScore = 40 } else if value >= 2690 { finalScore = 30 } else if value >= 2520 { finalScore = 20 } else if value >= 2350 { finalScore = 10 }
                }

            case "50米跑":
                if !isJuniorSenior
                {
                    if value <= 6.7 { finalScore = 100 } else if value <= 6.8 { finalScore = 95 } else if value <= 6.9 { finalScore = 90 } else if value <= 7.1 { finalScore = 85 } else if value <= 7.3 { finalScore = 80 } else if value <= 7.5 { finalScore = 78 } else if value <= 7.7 { finalScore = 76 } else if value <= 7.9 { finalScore = 74 } else if value <= 8.1 { finalScore = 72 } else if value <= 8.3 { finalScore = 70 } else if value <= 8.5 { finalScore = 68 } else if value <= 8.7 { finalScore = 66 } else if value <= 8.9 { finalScore = 64 } else if value <= 9.0 { finalScore = 62 } else if value <= 9.1 { finalScore = 60 } else if value <= 9.3 { finalScore = 50 } else if value <= 9.5 { finalScore = 40 } else if value <= 9.7 { finalScore = 30 } else if value <= 9.9 { finalScore = 20 } else if value <= 10.1 { finalScore = 10 }
                }
                else
                {
                    if value <= 6.6 { finalScore = 100 } else if value <= 6.7 { finalScore = 95 } else if value <= 6.8 { finalScore = 90 } else if value <= 7.0 { finalScore = 85 } else if value <= 7.2 { finalScore = 80 } else if value <= 7.4 { finalScore = 78 } else if value <= 7.6 { finalScore = 76 } else if value <= 7.8 { finalScore = 74 } else if value <= 8.0 { finalScore = 72 } else if value <= 8.2 { finalScore = 70 } else if value <= 8.4 { finalScore = 68 } else if value <= 8.6 { finalScore = 66 } else if value <= 8.8 { finalScore = 64 } else if value <= 8.9 { finalScore = 62 } else if value <= 9.0 { finalScore = 60 } else if value <= 9.2 { finalScore = 50 } else if value <= 9.4 { finalScore = 40 } else if value <= 9.6 { finalScore = 30 } else if value <= 9.8 { finalScore = 20 } else if value <= 10.0 { finalScore = 10 }
                }

            case "坐位体前屈":
                if !isJuniorSenior
                {
                    if value >= 24.9 { finalScore = 100 } else if value >= 23.1 { finalScore = 95 } else if value >= 21.3 { finalScore = 90 } else if value >= 19.5 { finalScore = 85 } else if value >= 17.7 { finalScore = 80 } else if value >= 16.3 { finalScore = 78 } else if value >= 14.9 { finalScore = 76 } else if value >= 13.5 { finalScore = 74 } else if value >= 12.1 { finalScore = 72 } else if value >= 10.7 { finalScore = 70 } else if value >= 9.3 { finalScore = 68 } else if value >= 7.9 { finalScore = 66 } else if value >= 6.5 { finalScore = 64 } else if value >= 5.1 { finalScore = 62 } else if value >= 3.7 { finalScore = 60 } else if value >= 2.7 { finalScore = 50 } else if value >= 1.7 { finalScore = 40 } else if value >= 0.7 { finalScore = 30 } else if value >= -0.3 { finalScore = 20 } else if value >= -1.3 { finalScore = 10 }
                }
                else
                {
                    if value >= 26.1 { finalScore = 100 } else if value >= 24.2 { finalScore = 95 } else if value >= 22.3 { finalScore = 90 } else if value >= 20.3 { finalScore = 85 } else if value >= 18.2 { finalScore = 80 } else if value >= 16.8 { finalScore = 78 } else if value >= 15.4 { finalScore = 76 } else if value >= 14.0 { finalScore = 74 } else if value >= 12.6 { finalScore = 72 } else if value >= 11.2 { finalScore = 70 } else if value >= 9.8 { finalScore = 68 } else if value >= 8.4 { finalScore = 66 } else if value >= 7.0 { finalScore = 64 } else if value >= 5.6 { finalScore = 62 } else if value >= 4.2 { finalScore = 60 } else if value >= 3.2 { finalScore = 50 } else if value >= 2.2 { finalScore = 40 } else if value >= 1.2 { finalScore = 30 } else if value >= 0.2 { finalScore = 20 } else if value >= -0.8 { finalScore = 10 }
                }

            case "立定跳远":
                if !isJuniorSenior
                {
                    if value >= 273 { finalScore = 100 } else if value >= 268 { finalScore = 95 } else if value >= 263 { finalScore = 90 } else if value >= 256 { finalScore = 85 } else if value >= 248 { finalScore = 80 } else if value >= 244 { finalScore = 78 } else if value >= 240 { finalScore = 76 } else if value >= 236 { finalScore = 74 } else if value >= 232 { finalScore = 72 } else if value >= 228 { finalScore = 70 } else if value >= 224 { finalScore = 68 } else if value >= 220 { finalScore = 66 } else if value >= 216 { finalScore = 64 } else if value >= 212 { finalScore = 62 } else if value >= 208 { finalScore = 60 } else if value >= 203 { finalScore = 50 } else if value >= 198 { finalScore = 40 } else if value >= 193 { finalScore = 30 } else if value >= 188 { finalScore = 20 } else if value >= 183 { finalScore = 10 }
                }
                else
                {
                    if value >= 275 { finalScore = 100 } else if value >= 270 { finalScore = 95 } else if value >= 265 { finalScore = 90 } else if value >= 258 { finalScore = 85 } else if value >= 250 { finalScore = 80 } else if value >= 246 { finalScore = 78 } else if value >= 242 { finalScore = 76 } else if value >= 238 { finalScore = 74 } else if value >= 234 { finalScore = 72 } else if value >= 230 { finalScore = 70 } else if value >= 226 { finalScore = 68 } else if value >= 222 { finalScore = 66 } else if value >= 218 { finalScore = 64 } else if value >= 214 { finalScore = 62 } else if value >= 210 { finalScore = 60 } else if value >= 205 { finalScore = 50 } else if value >= 200 { finalScore = 40 } else if value >= 195 { finalScore = 30 } else if value >= 190 { finalScore = 20 } else if value >= 185 { finalScore = 10 }
                }

            case "引体向上":
                if !isJuniorSenior
                {
                    if value >= 19 { finalScore = 100 } else if value >= 18 { finalScore = 95 } else if value >= 17 { finalScore = 90 } else if value >= 16 { finalScore = 85 } else if value >= 15 { finalScore = 80 } else if value >= 14 { finalScore = 76 } else if value >= 13 { finalScore = 72 } else if value >= 12 { finalScore = 68 } else if value >= 11 { finalScore = 64 } else if value >= 10 { finalScore = 60 } else if value >= 9 { finalScore = 50 } else if value >= 8 { finalScore = 40 } else if value >= 7 { finalScore = 30 } else if value >= 6 { finalScore = 20 } else if value >= 5 { finalScore = 10 }
                }
                else
                {
                    if value >= 20 { finalScore = 100 } else if value >= 19 { finalScore = 95 } else if value >= 18 { finalScore = 90 } else if value >= 17 { finalScore = 85 } else if value >= 16 { finalScore = 80 } else if value >= 15 { finalScore = 76 } else if value >= 14 { finalScore = 72 } else if value >= 13 { finalScore = 68 } else if value >= 12 { finalScore = 64 } else if value >= 11 { finalScore = 60 } else if value >= 10 { finalScore = 50 } else if value >= 9 { finalScore = 40 } else if value >= 8 { finalScore = 30 } else if value >= 7 { finalScore = 20 } else if value >= 6 { finalScore = 10 }
                }

            case "1000米跑":
                // 这里的输入应该是秒数，或者你在外层处理成秒
                if !isJuniorSenior
                {
                    if value <= 207 { finalScore = 100 } else if value <= 212 { finalScore = 95 } else if value <= 217 { finalScore = 90 } else if value <= 227 { finalScore = 85 } else if value <= 237 { finalScore = 80 } else if value <= 242 { finalScore = 78 } else if value <= 247 { finalScore = 76 } else if value <= 252 { finalScore = 74 } else if value <= 257 { finalScore = 72 } else if value <= 262 { finalScore = 70 } else if value <= 267 { finalScore = 68 } else if value <= 272 { finalScore = 66 } else if value <= 277 { finalScore = 64 } else if value <= 282 { finalScore = 62 } else if value <= 287 { finalScore = 60 } else if value <= 302 { finalScore = 50 } else if value <= 317 { finalScore = 40 } else if value <= 332 { finalScore = 30 } else if value <= 347 { finalScore = 20 } else if value <= 362 { finalScore = 10 }
                }
                else
                {
                    if value <= 210 { finalScore = 100 } else if value <= 215 { finalScore = 95 } else if value <= 220 { finalScore = 90 } else if value <= 230 { finalScore = 85 } else if value <= 240 { finalScore = 80 } else if value <= 245 { finalScore = 78 } else if value <= 250 { finalScore = 76 } else if value <= 255 { finalScore = 74 } else if value <= 260 { finalScore = 72 } else if value <= 265 { finalScore = 70 } else if value <= 270 { finalScore = 68 } else if value <= 275 { finalScore = 66 } else if value <= 280 { finalScore = 64 } else if value <= 285 { finalScore = 62 } else if value <= 290 { finalScore = 60 } else if value <= 305 { finalScore = 50 } else if value <= 320 { finalScore = 40 } else if value <= 335 { finalScore = 30 } else if value <= 350 { finalScore = 20 } else if value <= 365 { finalScore = 10 }
                }

            default: break
            }
        }
        else // 女生逻辑
        {
            switch project
            {
            case "肺活量":
                if !isJuniorSenior
                { // 大一二
                    if value >= 3400 { finalScore = 100 } else if value >= 3350 { finalScore = 95 } else if value >= 3300 { finalScore = 90 } else if value >= 3150 { finalScore = 85 } else if value >= 3000 { finalScore = 80 } else if value >= 2900 { finalScore = 78 } else if value >= 2800 { finalScore = 76 } else if value >= 2700 { finalScore = 74 } else if value >= 2600 { finalScore = 72 } else if value >= 2500 { finalScore = 70 } else if value >= 2400 { finalScore = 68 } else if value >= 2300 { finalScore = 66 } else if value >= 2200 { finalScore = 64 } else if value >= 2100 { finalScore = 62 } else if value >= 2000 { finalScore = 60 } else if value >= 1960 { finalScore = 50 } else if value >= 1920 { finalScore = 40 } else if value >= 1880 { finalScore = 30 } else if value >= 1840 { finalScore = 20 } else if value >= 1800 { finalScore = 10 }
                }
                else
                { // 大三四
                    if value >= 3450 { finalScore = 100 } else if value >= 3400 { finalScore = 95 } else if value >= 3350 { finalScore = 90 } else if value >= 3200 { finalScore = 85 } else if value >= 3050 { finalScore = 80 } else if value >= 2950 { finalScore = 78 } else if value >= 2850 { finalScore = 76 } else if value >= 2750 { finalScore = 74 } else if value >= 2650 { finalScore = 72 } else if value >= 2550 { finalScore = 70 } else if value >= 2450 { finalScore = 68 } else if value >= 2350 { finalScore = 66 } else if value >= 2250 { finalScore = 64 } else if value >= 2150 { finalScore = 62 } else if value >= 2050 { finalScore = 60 } else if value >= 2010 { finalScore = 50 } else if value >= 1970 { finalScore = 40 } else if value >= 1930 { finalScore = 30 } else if value >= 1890 { finalScore = 20 } else if value >= 1850 { finalScore = 10 }
                }

            case "50米跑":
                if !isJuniorSenior
                {
                    if value <= 7.5 { finalScore = 100 } else if value <= 7.6 { finalScore = 95 } else if value <= 7.7 { finalScore = 90 } else if value <= 8.0 { finalScore = 85 } else if value <= 8.3 { finalScore = 80 } else if value <= 8.5 { finalScore = 78 } else if value <= 8.7 { finalScore = 76 } else if value <= 8.9 { finalScore = 74 } else if value <= 9.1 { finalScore = 72 } else if value <= 9.3 { finalScore = 70 } else if value <= 9.5 { finalScore = 68 } else if value <= 9.7 { finalScore = 66 } else if value <= 9.9 { finalScore = 64 } else if value <= 10.1 { finalScore = 62 } else if value <= 10.3 { finalScore = 60 } else if value <= 10.5 { finalScore = 50 } else if value <= 10.7 { finalScore = 40 } else if value <= 10.9 { finalScore = 30 } else if value <= 11.1 { finalScore = 20 } else if value <= 11.3 { finalScore = 10 }
                }
                else
                {
                    if value <= 7.4 { finalScore = 100 } else if value <= 7.5 { finalScore = 95 } else if value <= 7.6 { finalScore = 90 } else if value <= 7.9 { finalScore = 85 } else if value <= 8.2 { finalScore = 80 } else if value <= 8.4 { finalScore = 78 } else if value <= 8.6 { finalScore = 76 } else if value <= 8.8 { finalScore = 74 } else if value <= 9.0 { finalScore = 72 } else if value <= 9.2 { finalScore = 70 } else if value <= 9.4 { finalScore = 68 } else if value <= 9.6 { finalScore = 66 } else if value <= 9.8 { finalScore = 64 } else if value <= 10.0 { finalScore = 62 } else if value <= 10.2 { finalScore = 60 } else if value <= 10.4 { finalScore = 50 } else if value <= 10.6 { finalScore = 40 } else if value <= 10.8 { finalScore = 30 } else if value <= 11.0 { finalScore = 20 } else if value <= 11.2 { finalScore = 10 }
                }

            case "坐位体前屈":
                if !isJuniorSenior
                {
                    if value >= 26.3 { finalScore = 100 } else if value >= 24.1 { finalScore = 95 } else if value >= 21.9 { finalScore = 90 } else if value >= 19.5 { finalScore = 85 } else if value >= 17.2 { finalScore = 80 } else if value >= 15.6 { finalScore = 78 } else if value >= 14.1 { finalScore = 76 } else if value >= 12.6 { finalScore = 74 } else if value >= 11.1 { finalScore = 72 } else if value >= 9.6 { finalScore = 70 } else if value >= 8.1 { finalScore = 68 } else if value >= 6.6 { finalScore = 66 } else if value >= 5.1 { finalScore = 64 } else if value >= 3.6 { finalScore = 62 } else if value >= 2.1 { finalScore = 60 } else if value >= 1.1 { finalScore = 50 } else if value >= 0.1 { finalScore = 40 } else if value >= -0.9 { finalScore = 30 } else if value >= -1.9 { finalScore = 20 } else if value >= -2.9 { finalScore = 10 }
                }
                else
                {
                    if value >= 27.0 { finalScore = 100 } else if value >= 24.8 { finalScore = 95 } else if value >= 22.6 { finalScore = 90 } else if value >= 20.1 { finalScore = 85 } else if value >= 17.7 { finalScore = 80 } else if value >= 16.1 { finalScore = 78 } else if value >= 14.6 { finalScore = 76 } else if value >= 13.1 { finalScore = 74 } else if value >= 11.6 { finalScore = 72 } else if value >= 10.1 { finalScore = 70 } else if value >= 8.6 { finalScore = 68 } else if value >= 7.1 { finalScore = 66 } else if value >= 5.6 { finalScore = 64 } else if value >= 4.1 { finalScore = 62 } else if value >= 2.6 { finalScore = 60 } else if value >= 1.6 { finalScore = 50 } else if value >= 0.6 { finalScore = 40 } else if value >= -0.4 { finalScore = 30 } else if value >= -1.4 { finalScore = 20 } else if value >= -2.4 { finalScore = 10 }
                }

            case "立定跳远":
                if !isJuniorSenior
                {
                    if value >= 207 { finalScore = 100 } else if value >= 201 { finalScore = 95 } else if value >= 195 { finalScore = 90 } else if value >= 188 { finalScore = 85 } else if value >= 181 { finalScore = 80 } else if value >= 178 { finalScore = 78 } else if value >= 175 { finalScore = 76 } else if value >= 172 { finalScore = 74 } else if value >= 169 { finalScore = 72 } else if value >= 166 { finalScore = 70 } else if value >= 163 { finalScore = 68 } else if value >= 160 { finalScore = 66 } else if value >= 157 { finalScore = 64 } else if value >= 154 { finalScore = 62 } else if value >= 151 { finalScore = 60 } else if value >= 146 { finalScore = 50 } else if value >= 141 { finalScore = 40 } else if value >= 136 { finalScore = 30 } else if value >= 131 { finalScore = 20 } else if value >= 126 { finalScore = 10 }
                }
                else
                {
                    if value >= 208 { finalScore = 100 } else if value >= 202 { finalScore = 95 } else if value >= 196 { finalScore = 90 } else if value >= 189 { finalScore = 85 } else if value >= 182 { finalScore = 80 } else if value >= 179 { finalScore = 78 } else if value >= 176 { finalScore = 76 } else if value >= 173 { finalScore = 74 } else if value >= 170 { finalScore = 72 } else if value >= 167 { finalScore = 70 } else if value >= 164 { finalScore = 68 } else if value >= 161 { finalScore = 66 } else if value >= 158 { finalScore = 64 } else if value >= 155 { finalScore = 62 } else if value >= 152 { finalScore = 60 } else if value >= 147 { finalScore = 50 } else if value >= 142 { finalScore = 40 } else if value >= 137 { finalScore = 30 } else if value >= 132 { finalScore = 20 } else if value >= 127 { finalScore = 10 }
                }

            case "仰卧起坐":
                if !isJuniorSenior
                {
                    if value >= 56 { finalScore = 100 } else if value >= 54 { finalScore = 95 } else if value >= 52 { finalScore = 90 } else if value >= 49 { finalScore = 85 } else if value >= 46 { finalScore = 80 } else if value >= 44 { finalScore = 78 } else if value >= 42 { finalScore = 76 } else if value >= 40 { finalScore = 74 } else if value >= 38 { finalScore = 72 } else if value >= 36 { finalScore = 70 } else if value >= 34 { finalScore = 68 } else if value >= 32 { finalScore = 66 } else if value >= 30 { finalScore = 64 } else if value >= 28 { finalScore = 62 } else if value >= 26 { finalScore = 60 } else if value >= 24 { finalScore = 50 } else if value >= 22 { finalScore = 40 } else if value >= 20 { finalScore = 30 } else if value >= 18 { finalScore = 20 } else if value >= 16 { finalScore = 10 }
                }
                else
                {
                    if value >= 57 { finalScore = 100 } else if value >= 55 { finalScore = 95 } else if value >= 53 { finalScore = 90 } else if value >= 50 { finalScore = 85 } else if value >= 47 { finalScore = 80 } else if value >= 45 { finalScore = 78 } else if value >= 43 { finalScore = 76 } else if value >= 41 { finalScore = 74 } else if value >= 39 { finalScore = 72 } else if value >= 37 { finalScore = 70 } else if value >= 35 { finalScore = 68 } else if value >= 33 { finalScore = 66 } else if value >= 31 { finalScore = 64 } else if value >= 29 { finalScore = 62 } else if value >= 27 { finalScore = 60 } else if value >= 25 { finalScore = 50 } else if value >= 23 { finalScore = 40 } else if value >= 21 { finalScore = 30 } else if value >= 19 { finalScore = 20 } else if value >= 17 { finalScore = 10 }
                }

            case "800米跑":
                if !isJuniorSenior
                {
                    if value <= 198 { finalScore = 100 } else if value <= 204 { finalScore = 95 } else if value <= 210 { finalScore = 90 } else if value <= 217 { finalScore = 85 } else if value <= 224 { finalScore = 80 } else if value <= 229 { finalScore = 78 } else if value <= 234 { finalScore = 76 } else if value <= 239 { finalScore = 74 } else if value <= 244 { finalScore = 72 } else if value <= 249 { finalScore = 70 } else if value <= 254 { finalScore = 68 } else if value <= 259 { finalScore = 66 } else if value <= 264 { finalScore = 64 } else if value <= 269 { finalScore = 62 } else if value <= 274 { finalScore = 60 } else if value <= 284 { finalScore = 50 } else if value <= 294 { finalScore = 40 } else if value <= 304 { finalScore = 30 } else if value <= 314 { finalScore = 20 } else if value <= 324 { finalScore = 10 }
                }
                else
                {
                    if value <= 200 { finalScore = 100 } else if value <= 206 { finalScore = 95 } else if value <= 212 { finalScore = 90 } else if value <= 219 { finalScore = 85 } else if value <= 226 { finalScore = 80 } else if value <= 231 { finalScore = 78 } else if value <= 236 { finalScore = 76 } else if value <= 241 { finalScore = 74 } else if value <= 246 { finalScore = 72 } else if value <= 251 { finalScore = 70 } else if value <= 256 { finalScore = 68 } else if value <= 261 { finalScore = 66 } else if value <= 266 { finalScore = 64 } else if value <= 271 { finalScore = 62 } else if value <= 276 { finalScore = 60 } else if value <= 286 { finalScore = 50 } else if value <= 296 { finalScore = 40 } else if value <= 306 { finalScore = 30 } else if value <= 316 { finalScore = 20 } else if value <= 326 { finalScore = 10 }
                }

            default: break
            }
        }

        return (finalScore, getGrade(from: finalScore))
    }

    static func totalGrade(score: Double) -> String
    {
        if score >= 90 { return "优秀" }
        if score >= 80 { return "良好" }
        if score >= 60 { return "及格" }
        return "不及格"
    }
}

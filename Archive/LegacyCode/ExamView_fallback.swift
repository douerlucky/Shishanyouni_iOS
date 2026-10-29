////
////  ExamView.swift
////  shishanyouni
////
//
//import SwiftUI
//
//struct ExamView: View {
//    @EnvironmentObject var userinfo: userInfo
//    @State var exams: [Exam] = []
//    @State private var isLoading = false
//
//    @State private var showAlert   = false
//    @State private var alertMessage = ""
//    @State private var alertTitle   = ""
//
//    @State var selectedYear = "2025"
//    @State var selectedTerm = "2"   // 默认春季学期
//
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
//
//            ZStack {
//                if exams.isEmpty {
//                    VStack {
//                        Spacer()
//                        Image(systemName: "calendar.badge.exclamationmark")
//                            .font(.system(size: 50))
//                            .foregroundColor(.secondary.opacity(0.6))
//                            .padding(.bottom, 8)
//                        Text("未查询到任何考试安排")
//                            .font(.title3)
//                            .foregroundColor(.secondary)
//                        Spacer()
//                    }
//                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .blur(radius: isLoading ? 3 : 0)
//                } else {
//                    List(exams) { item in
//                        ExamCard(exam: item)
//                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
//                            .listRowSeparator(.hidden)
//                            .listRowBackground(Color.clear)
//                    }
//                    .listStyle(.plain)
//                    .scrollContentBackground(.hidden)
//                    .background(Color.clear)
//                    .blur(radius: isLoading ? 3 : 0)
//                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
//                }
//
//                if isLoading {
//                    VStack(spacing: 12) {
//                        ProgressView().tint(.blue)
//                        Text("正在努力加载考试信息...")
//                            .font(.subheadline)
//                            .foregroundColor(.secondary)
//                    }
//                    .padding(25)
//                    .background(Color(.systemBackground).opacity(0.8))
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//                }
//            }
//
//            ExamBottomControlBar(
//                isLoading:    $isLoading,
//                exams:        $exams,
//                showAlert:    $showAlert,
//                alertTitle:   $alertTitle,
//                alertMessage: $alertMessage,
//                selectedYear: $selectedYear,
//                selectedTerm: $selectedTerm
//            )
//        }
//        .navigationTitle("我的考试")
//        .toolbar(.hidden, for: .tabBar)
//        .alert(alertTitle, isPresented: $showAlert) {
//            Button("好的", role: .cancel) { }
//        } message: {
//            Text(alertMessage)
//        }
//    }
//}
//
//// MARK: - 考试卡片
//
//struct ExamCard: View {
//    let exam: Exam
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            HStack(alignment: .top) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(exam.kcmc)
//                        .font(.title2)
//                        .foregroundColor(.primary)
//
//                    Text(exam.ksmc)
//                        .font(.caption)
//                        .padding(.horizontal, 8)
//                        .padding(.vertical, 2)
//                        .background(Color.blue.opacity(0.1))
//                        .foregroundColor(.blue)
//                        .cornerRadius(4)
//                }
//                Spacer()
//                if let bj = exam.bj {
//                    Text(bj)
//                        .font(.system(size: 13, weight: .medium))
//                        .foregroundColor(.secondary)
//                }
//            }
//
//            VStack(alignment: .leading, spacing: 8) {
//                HStack {
//                    Image(systemName: "calendar")
//                        .font(.system(size: 20, weight: .semibold))
//                        .foregroundColor(.orange)
//                        .frame(width: 24)
//                    Text(exam.examDate)
//                        .font(.system(size: 20, weight: .semibold))
//                    Text(exam.examTime)
//                        .font(.system(size: 20, weight: .semibold))
//                }
//
//                HStack(spacing: 15) {
//                    HStack {
//                        Image(systemName: "mappin.and.ellipse")
//                            .foregroundColor(.red)
//                            .font(.system(size: 16, weight: .semibold))
//                            .frame(width: 16)
//                        Text(exam.cdmc ?? "未指定场地")
//                            .font(.system(size: 16, weight: .semibold))
//                    }
//
//                    if let zwh = exam.zwh, !zwh.isEmpty {
//                        HStack {
//                            Image(systemName: "number.square")
//                                .foregroundColor(.green)
//                                .font(.system(size: 16, weight: .semibold))
//                                .frame(width: 18)
//                            Text("座位: \(zwh)")
//                                .font(.system(size: 16, weight: .semibold))
//                        }
//                    }
//                }
//            }
//            .font(.subheadline)
//            .foregroundColor(.secondary)
//        }
//        .padding(16)
//        .background(
//            RoundedRectangle(cornerRadius: 20)
//                .fill(Color(uiColor: .secondarySystemGroupedBackground))
//                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
//        )
//    }
//}
//
//// MARK: - 底部控制条
//
//struct ExamBottomControlBar: View {
//    @Binding var isLoading: Bool
//    @Binding var exams: [Exam]
//    @Binding var showAlert: Bool
//    @Binding var alertTitle: String
//    @Binding var alertMessage: String
//    @Binding var selectedYear: String
//    @Binding var selectedTerm: String
//
//    @State private var showPicker = false
//    @EnvironmentObject var userinfo: userInfo
//
//    let years = ["2023", "2024", "2025", "2026"]
//    let terms = [("第一学期", "1"), ("第二学期", "2")]
//
//    var body: some View {
//        HStack(spacing: 15) {
//            Button(action: { showPicker = true }) {
//                HStack {
//                    Text("\(formatYearAbbr(selectedYear)) \(termShortName(selectedTerm))")
//                        .font(.system(size: 14, weight: .bold))
//                    Image(systemName: "chevron.up")
//                        .font(.system(size: 10, weight: .bold))
//                }
//                .padding(.horizontal, 16)
//                .padding(.vertical, 10)
//                .background(Color(.systemBackground).opacity(0.9))
//                .clipShape(Capsule())
//            }
//            .optionalLiquidGlass()
//
//            Button(action: { fetchExamData() }) {
//                HStack(spacing: 6) {
//                    Image(systemName: "magnifyingglass")
//                    Text("查询")
//                }
//                .font(.system(size: 15, weight: .bold))
//                .foregroundColor(.white)
//                .padding(.horizontal, 24)
//                .padding(.vertical, 10)
//                .background(Color.blue)
//                .clipShape(Capsule())
//            }
//            .optionalLiquidGlass()
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 15)
//        .glassBackground(cornerRadius: 64)
//        .padding(.bottom, 25)
//        .sheet(isPresented: $showPicker) {
//            VStack(spacing: 20) {
//                Text("选择查询范围")
//                    .font(.headline)
//                    .padding(.top, 20)
//
//                HStack(spacing: 0) {
//                    Picker("年份", selection: $selectedYear) {
//                        ForEach(years, id: \.self) { year in
//                            if let y = Int(year) {
//                                Text("\(year)-\(y + 1)学年").tag(year)
//                            } else {
//                                Text("\(year)学年").tag(year)
//                            }
//                        }
//                    }
//                    .pickerStyle(.wheel)
//
//                    Picker("学期", selection: $selectedTerm) {
//                        ForEach(terms, id: \.1) { Text($0.0).tag($0.1) }
//                    }
//                    .pickerStyle(.wheel)
//                }
//
//                Button(action: { showPicker = false }) {
//                    Text("确定")
//                        .bold()
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(12)
//                }
//                .optionalLiquidGlass()
//                .padding(.horizontal, 25)
//                .padding(.bottom, 20)
//            }
//            .presentationDetents([.height(350)])
//        }
//    }
//
//    private func formatYearAbbr(_ year: String) -> String {
//        guard let y = Int(year) else { return year }
//        return String(format: "%02d-%02d", y % 100, (y + 1) % 100)
//    }
//
//    private func termShortName(_ term: String) -> String {
//        switch term {
//        case "1": return "一"
//        case "2": return "二"
//        default:  return "一"
//        }
//    }
//
//    private func fetchExamData() {
//        guard !userinfo.username.isEmpty else {
//            alertTitle   = "未登录"
//            alertMessage = "请先在个人页面登录"
//            showAlert    = true
//            return
//        }
//
//        let password = userinfo.plainPassword
//        guard !password.isEmpty else {
//            alertTitle   = "查询失败"
//            alertMessage = "未找到密码，请重新登录"
//            showAlert    = true
//            return
//        }
//
//        isLoading = true
//        Task {
//            do {
//                let result = try await ExamService.fetchExams(
//                    username: userinfo.username,
//                    password: userinfo.plainPassword,
//                    year:     selectedYear,
//                    term:     selectedTerm
//                )
//
//                await MainActor.run {
//                    self.exams     = result
//                    self.isLoading = false
//                    if result.isEmpty {
//                        self.alertTitle   = "提示"
//                        self.alertMessage = "该学期未查询到考试安排"
//                        self.showAlert    = true
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    self.isLoading    = false
//                    self.alertTitle   = "查询失败"
//                    self.alertMessage = error.localizedDescription
//                    self.showAlert    = true
//                }
//            }
//        }
//    }
//}
//
//#Preview {
//    ExamView().environmentObject(userInfo())
//}

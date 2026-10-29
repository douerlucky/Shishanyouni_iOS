import SwiftUI

// MARK: - 教室位置选择器

struct PickerSheetView: View
{
    @Environment(\.dismiss) var dismiss

    @Binding var selectedBuilding: String
    @Binding var selectedWing: String
    @Binding var selectedFloor: Int

    let buildings: [String]
    let availableWings: [String]
    let maxFloor: Int

    var body: some View
    {
        NavigationView
        {
            VStack(spacing: 20)
            {
                Text("教室位置")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                HStack(spacing: 0)
                {
                    Picker("教学楼", selection: $selectedBuilding)
                    {
                        ForEach(buildings, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .onChange(of: selectedBuilding)
                    { newValue in
                        if newValue == "一教" || newValue == "二教" || newValue == "襄阳校区二教" { selectedWing = "无" }
                        else if selectedWing == "无" { selectedWing = "A" }
                        validateFloor()
                    }

                    let wingDisabled = selectedBuilding == "一教" || selectedBuilding == "二教" || selectedBuilding == "襄阳校区二教"

                    Picker("栋号", selection: $selectedWing)
                    {
                        ForEach(availableWings, id: \.self)
                        { wing in
                            Text(wing == "无" ? "不分栋" : "\(wing)栋").tag(wing)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                    .onChange(of: selectedWing) { _ in validateFloor() }
                    .opacity(wingDisabled ? 0.3 : 1.0)
                    .disabled(wingDisabled)

                    Picker("楼层", selection: $selectedFloor)
                    {
                        ForEach(1 ... maxFloor, id: \.self) { Text("\($0) 楼").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()
                }
                .padding(.horizontal, 10)

                Spacer()
            }
            .navigationTitle("教学楼过滤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar
            {
                ToolbarItem(placement: .confirmationAction)
                {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300), .medium])
    }

    private func validateFloor()
    {
        if selectedFloor > maxFloor { selectedFloor = maxFloor }
    }
}

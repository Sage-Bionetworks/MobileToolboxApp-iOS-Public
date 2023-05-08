//
//  ContentView.swift
//

import SwiftUI
import BridgeClientExtension
import BridgeClientUI
import Research
import AssessmentModel
import AssessmentModelUI

public let kAssessmentInfoMap: AssessmentInfoMap = .init(extensions: MTBIdentifier.allCases, defaultColor: MTBIdentifier.defaultColor)

public struct ContentView: View {
    @EnvironmentObject var bridgeManager: SingleStudyAppManager
    @StateObject var todayViewModel: TodayTimelineViewModel = .init()
    @State var isPresentingAssessment: Bool = false
    
    public init() {}
    
    public var body: some View {
        switch bridgeManager.appState {
        case .launching:
            LaunchView()
        case .login:
            if let externalId = bridgeManager.userSessionInfo.externalId,
               externalId.contains(":"),
               bridgeManager.userSessionInfo.loginState == .reauthFailed {
                let parts = externalId.components(separatedBy: ":")
                ReauthRecoveryView(studyId: parts.first!, participantId: parts.last!)
            }
            else {
                SingleStudyLoginView()
            }
        case .onboarding:
            OnboardingView()
                .onAppear {
                    // Start fetching records and schedules on login
                    todayViewModel.onAppear(bridgeManager: bridgeManager)
                }
        case .main:
            MainView()
                .environmentObject(todayViewModel)
                .assessmentInfoMap(kAssessmentInfoMap)
                .fullScreenCover(isPresented: $isPresentingAssessment) {
                    assessmentView()
                }
                .onChange(of: todayViewModel.isPresentingAssessment) { newValue in
                    if newValue, let info = todayViewModel.selectedAssessment {
                        Logger.log(severity: .info,
                                   message: "Presenting Assessment \(info.assessmentIdentifier)",
                                   metadata: [
                                    "instanceGuid": info.instanceGuid,
                                    "assessmentIdentifier": info.assessmentIdentifier,
                                    "sessionInstanceGuid": info.session.instanceGuid,
                                   ])
                    }
                    isPresentingAssessment = newValue
                }
        case .error:
            AppErrorView()
        }
    }
    
    @ViewBuilder
    func assessmentView() -> some View {
        switch todayViewModel.selectedAssessmentViewType {
        case .mtb(let info):
            if #available(iOS 16.0, *) {
                mtbView(info)
                    .statusBar(hidden: todayViewModel.isPresentingAssessment)
                    .defersSystemGestures(on: .vertical)
            } else {
                PreferenceUIHostingControllerView {
                    mtbView(info)
                }
                .edgesIgnoringSafeArea(.all)
                .statusBar(hidden: todayViewModel.isPresentingAssessment)
            }
        case .survey(let info):
            SurveyView<AssessmentView>(info, handler: todayViewModel)
        default:
            emptyAssessment()
        }
    }
    
    @ViewBuilder
    func mtbView(_ info: AssessmentScheduleInfo) -> some View {
        MTBAssessmentView(info, handler: todayViewModel)
            .edgesIgnoringSafeArea(.all)
    }
    
    @ViewBuilder
    func emptyAssessment() -> some View {
        VStack {
            Text("This assessment is not supported by this app version")
            Button("Dismiss", action: { todayViewModel.isPresentingAssessment = false })
        }
    }
}

enum AssessmentViewType {
    case mtb(AssessmentScheduleInfo)
    case survey(AssessmentScheduleInfo)
    case empty
}

extension TodayTimelineViewModel {
    
    var selectedAssessmentViewType : AssessmentViewType {
        guard let info = selectedAssessment else { return .empty }
        
        let assessmentId = info.assessmentInfo.identifier
        if let _ = MTBIdentifier(rawValue: assessmentId) {
            return .mtb(info)
        }
        else if taskVendor.taskTransformerMapping[assessmentId] != nil {
            return .mtb(info)
        }
        else {
            return .survey(info)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .environmentObject(SingleStudyAppManager(appId: kPreviewStudyId))
        }
    }
}

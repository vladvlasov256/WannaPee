//
//  Analytics.swift
//  WannaPee
//
//  Created by Vladimir Vlasov on 05.05.2018.
//  Copyright © 2018 Sofatech. All rights reserved.
//

#if DEBUG
func logContentView(name: String, type: String, id: String? = nil) {
    print("Content view \"\(name)\" of type \"\(type)\" with id \"\(id ?? "null")\"")
}

func logOfflineMapAction(map: String, action: String) {
    print("Offline map action \"\(action)\" with \(map)")
}

func logPickToilet(in city: String?) {
    print("Pick a toilet in \(city ?? "unknown")")
}

func logShowRoute(in city: String?) {
    print("Show a route in \(city ?? "unknown")")
}

func logHideRoute(in city: String?) {
    print("Hide a route in \(city ?? "unknown")")
}

func log(feedback: FeedbackType, cancel: Bool, in city: String?) {
    if cancel {
        print("Cancel \(feedback) in \(city ?? "unknown")")
    } else {
        print("Sent \(feedback) in \(city ?? "unknown")")
    }
}

func log(city: String?) {
    print("One is in city \(city ?? "unknown")")
}

func logOfflineMapDownload(action: String) {
    print("User selected \(action)")
}

func logAddToilet() {
    print("User add a toilet")
}
#else
import Crashlytics

func logContentView(name: String, type: String, id: String? = nil) {
    Answers.logContentView(withName: name, contentType: type, contentId: id)
}

func logOfflineMapAction(map: String, action: String) {
    Answers.logCustomEvent(withName: action, customAttributes: ["map": map])
}

func logPickToilet(in city: String?) {
    Answers.logCustomEvent(withName: "pick", customAttributes: ["city": city ?? "unknown"])
}

func logShowRoute(in city: String?) {
    Answers.logCustomEvent(withName: "route", customAttributes: ["city": city ?? "unknown"])
}

func logHideRoute(in city: String?) {
    Answers.logCustomEvent(withName: "hide_route", customAttributes: ["city": city ?? "unknown"])
}

func log(feedback: FeedbackType, cancel: Bool, in city: String?) {
    if cancel {
        Answers.logCustomEvent(withName: "cancel_feedback", customAttributes: ["type": "\(feedback)", "city": city ?? "unknown"])
    } else {
        Answers.logCustomEvent(withName: "feedback", customAttributes: ["type": "\(feedback)", "city": city ?? "unknown"])
    }
}

func log(city: String?) {
    Answers.logCustomEvent(withName: "change_city", customAttributes: ["city": city ?? "unknown"])
}

func logOfflineMapDownload(action: String) {
    Answers.logCustomEvent(withName: "download_action", customAttributes: ["action": action])
}

func logAddToilet() {
    Answers.logCustomEvent(withName: "add_toilet", customAttributes: nil)
}
#endif

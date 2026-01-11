import XCTest
@testable import PointAppDomainTests

fileprivate extension PointAmountTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__PointAmountTests = [
        ("test_10ポイントは1円で換算できる", test_10ポイントは1円で換算できる),
        ("test_2つのPointAmountを加算できる", test_2つのPointAmountを加算できる),
        ("test_2つのPointAmountを比較できる", test_2つのPointAmountを比較できる),
        ("test_ゼロでPointAmountを作成できる", test_ゼロでPointAmountを作成できる),
        ("test_円表示の文字列を取得できる", test_円表示の文字列を取得できる),
        ("test_正の値でPointAmountを作成できる", test_正の値でPointAmountを作成できる),
        ("test_端数を含む円換算ができる", test_端数を含む円換算ができる),
        ("test_負の値の場合はエラー", test_負の値の場合はエラー)
    ]
}

fileprivate extension SurveyAnswerTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__SurveyAnswerTests = [
        ("test_単一選択の回答を作成できる", test_単一選択の回答を作成できる),
        ("test_複数選択の回答を作成できる", test_複数選択の回答を作成できる)
    ]
}

fileprivate extension SurveyQuestionTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__SurveyQuestionTests = [
        ("test_スケールの質問を作成できる", test_スケールの質問を作成できる),
        ("test_単一選択の質問を作成できる", test_単一選択の質問を作成できる),
        ("test_自由記述の質問を作成できる", test_自由記述の質問を作成できる),
        ("test_複数選択の質問を作成できる", test_複数選択の質問を作成できる)
    ]
}

fileprivate extension SurveyTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__SurveyTests = [
        ("test_報酬効率を計算できる", test_報酬効率を計算できる),
        ("test_所要時間が0の場合は効率0", test_所要時間が0の場合は効率0),
        ("test_期限内のアンケートは回答可能", test_期限内のアンケートは回答可能),
        ("test_期限切れのアンケートは回答不可", test_期限切れのアンケートは回答不可),
        ("test_期限切れの場合は残り時間nil", test_期限切れの場合は残り時間nil),
        ("test_残り時間を取得できる", test_残り時間を取得できる),
        ("test_高効率アンケートを判定できる", test_高効率アンケートを判定できる)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __PointAppDomainTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(PointAmountTests.__allTests__PointAmountTests),
        testCase(SurveyAnswerTests.__allTests__SurveyAnswerTests),
        testCase(SurveyQuestionTests.__allTests__SurveyQuestionTests),
        testCase(SurveyTests.__allTests__SurveyTests)
    ]
}
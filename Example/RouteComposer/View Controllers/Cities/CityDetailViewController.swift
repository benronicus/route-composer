//
// Created by Eugene Kazaev on 15/01/2018.
// Copyright © 2018 HBC Digital. All rights reserved.
//

import Foundation
import UIKit
import RouteComposer

class CityDetailContextTask: ContextTask {

    func perform(on viewController: CityDetailViewController, with context: Int) throws {
        viewController.cityId = context
    }

}

class CityDetailViewController: UIViewController, ExampleAnalyticsSupport {

    let screenType = ExampleScreenTypes.cityDetail

    @IBOutlet private var detailsTextView: UITextView!

    var cityId: Int? {
        didSet {
            reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()
    }

    private func reloadData() {
        guard isViewLoaded, let city = CitiesDataModel.cities.first(where: { $0.cityId == cityId }) else {
            return
        }
        self.title = "\(city.city)"

        detailsTextView.text = city.city + "\n\n" + city.description
        if let cityId = cityId {
            self.view.accessibilityIdentifier = "cityDetailsViewController+\(cityId)"
        } else {
            self.view.accessibilityIdentifier = "cityDetailsViewController"
        }
    }

    @IBAction func goToStarTapped() {
        try? router.navigate(to: ConfigurationHolder.configuration.starScreen, with: nil)
    }

    @IBAction func backProgrammaticallyTapped() {
        try? router.navigate(to: CitiesConfiguration.citiesList(cityId: nil))
    }

}

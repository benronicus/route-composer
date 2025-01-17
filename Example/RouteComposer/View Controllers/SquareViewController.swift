//
//  SquareViewController.swift
//  CircumferenceKit
//
//  Created by Eugene Kazaev on 18/12/2017.
//  Copyright © 2018 HBC Digital. All rights reserved.
//

import UIKit
import RouteComposer

class SquareViewController: UIViewController, ExampleAnalyticsSupport {

    let screenType = ExampleScreenTypes.square

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Square"
    }

    @IBAction func goToCircleTapped() {
        try? router.navigate(to: ConfigurationHolder.configuration.circleScreen, with: nil)
    }

    @IBAction func goToHomeTapped() {
        try? router.navigate(to: ConfigurationHolder.configuration.figuresScreen, with: nil)
    }

    @IBAction func goToSplitTapped() {
        try? router.navigate(to: CitiesConfiguration.citiesList())
    }

    @IBAction func goToLoginTapped() {
        try? router.navigate(to: LoginConfiguration.login())
    }

    @IBAction func goToStarTapped() {
        try? router.navigate(to: ConfigurationHolder.configuration.starScreen, with: nil)
    }

    @IBAction func goToFakeContainerTapped() {
        try? router.navigate(to: WishListConfiguration.collections())
    }

    @IBAction func goEmptyAndProductTapped() {
        try? router.navigate(to: ConfigurationHolder.configuration.figuresAndProductScreen, with: ProductContext(productId: "03"))
    }

    @IBAction func switchValueChanged(sender: UISwitch) {
        if sender.isOn {
            ConfigurationHolder.configuration = AlternativeExampleConfiguration()
        } else {
            ConfigurationHolder.configuration = ExampleConfiguration()
        }
    }

}

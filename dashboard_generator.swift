//
//  DashboardSelectorViewController.swift
//  Created by JoongHeum Park on 5/15/17.
//

import UIKit

let DASHBOARD = "dashboard"
let PAGES = "pages"
let ID = "id"
let CONTENTS = "contents"
let REFERENCES = "references"
let VARIABLEDESCRIPTION = "variableDescription"
let REUSABLES = "reusables"
let PARAGRAPHITEMS = "paragraphItems"



func toBool(_ text :String) -> Bool {
    switch text.lowercased() {
    case "true", "yes", "1":
        return true
    case "false", "no", "0":
        return false
    default:
        return false
    }
}

func parseReferences(_ text :String) -> [Int] {
    var references :[Int] = []
    
    if (text.trimmed() != "" ) {
        let ref_array = text.components(separatedBy: ",")
        for single in ref_array {
            if( Int(single) != nil  ) {
                references.append( Int(single)! )
            }
            
        }
    }
    
    return references
}


func buildRichText(text :String) -> String {
    
    var temp = ""
    
    let compo = text.components(separatedBy: "]]")
    for single in compo {
        let spt = single.components(separatedBy: "[[")
        if (spt.count == 2) {
            
            temp = temp + spt[0]
            
            if let numStr = getPredeterminedValue(id: spt[1]) {
                temp = temp + numStr
            } else if let numStr = getFormulaValue(id: spt[1]) {
                temp = temp + numStr
            }
            
        } else {
            
            temp = temp + spt[0]
        }
    }
    
    return temp
    
}



func buildRichStatements(text :String) -> [Statement] {
    
    var statements :[Statement] = []
    
    let compo = text.components(separatedBy: "]]")
    for single in compo {
        let spt = single.components(separatedBy: "[[")
        if (spt.count == 2) {
            statements.append(Statement(content: spt[0]))
            if  let linkedSt = reusableManager.getReusable(id: spt[1] )  {
                statements.append(linkedSt)
            } else if let numStr = getPredeterminedValue(id: spt[1]) {
                statements.append( Statement(content: numStr))
            } else if let numStr = getFormulaValue(id: spt[1]) {
                statements.append( Statement(content: numStr))
            } else if let comment = reusableManager.getReusableComment(id: spt[1]) {
                let sta = Statement(content: "")
                
                sta.addComment(comment)
                statements.append(sta)
            }
            
        } else {
            statements.append(Statement(content: spt[0]))
        }
    }
    
    return statements
}


func parseRichString(_ text :String) -> String {
    //var interpreted :String = text.replacingOccurrences(of: "|", with: "*n*")
    
    var interpreted = ""
    
    let bulletedArray = text.components(separatedBy: "|")
    for (index, single) in bulletedArray.enumerated() {
        if ( index != 0 ) { interpreted += "*n*" }
        interpreted = interpreted + "** "
        if single.contains("::") {
            interpreted = interpreted + "$$%" + single.replace(target: "::", withString: "$$: ")
        } else {
            interpreted = interpreted + single
        }
    }
    return interpreted
}

func getTriggerString(_ text :String) -> String {
    var pTriger :String = text.replacingOccurrences(of: "[", with: "")
    pTriger = pTriger.replacingOccurrences(of: "]", with: "")
    return pTriger
}

func extractDoubleDictFromVariableNames(variables :[String]) -> [String:Double] {
    var targetVariables :[String:Double] = [:]
    
    for singleVar in variables {
        targetVariables[singleVar] = Global.classStatusDouble[singleVar]
        if ( targetVariables[singleVar] == nil && Global.classStatusInt[singleVar] != nil ) {
            targetVariables[singleVar] = Double(Global.classStatusInt[singleVar]!)
        }
    }
    return targetVariables
}

func extractIntDictFromVariableNames(variables :[String]) -> [String:Int] {
    var targetVariables :[String:Int] = [:]
    
    for singleVar in variables {
        targetVariables[singleVar] = Global.classStatusInt[singleVar]
    }
    return targetVariables
}

func parseForVariables(_ text :String) -> [String] {
    var varsInterest :[String] = []
    
    var initiated = false
    var accStr = ""
    
    for char in text {
        
        
        if initiated == true {
            
            if char == "]" {
                initiated = false
                varsInterest.append(accStr)
                accStr = ""
            } else {
                accStr.append(char)
            }
        } else if char == "[" {
            
            initiated = true
        }
        
    }
    
    return varsInterest
}

struct ClinicalTarget {
    var name :String
    var id :String
    var title :String
    var creators :[String]
    var tapped :Bool
    var files :[String:String]
    

    init(data :[String]) {
        name = data[0]
        title = data[1]
        id = data[2]
        tapped = toBool(data[4])
        creators = data[3].components(separatedBy: "|")
        
        files = [:]
        files[DASHBOARD] = data[5]
        files[PAGES] = data[6]
        files[CONTENTS] = data[7]
        files[REFERENCES] = data[8]
        files[VARIABLEDESCRIPTION] = data[9]
        files[REUSABLES] = data[10]
        files[PARAGRAPHITEMS] = data[11]
    }
}

func getTarget(id :String, data: [[String]]) -> ClinicalTarget? {
    for singleData in data {
        if  (singleData[0] == "Name" || singleData[0] == "" ) {
            continue
        } else if (singleData[2].lowercased() == id.lowercased() ) {
            return ClinicalTarget(data: singleData)
        }
    }
    
    return nil
}

func pageCreator( pageListFile: String, contentFile: String, variableDescriptionFile: String , paragraphItemFile :String) -> [Page] {
    var pages :[Page] = []
    
    /*
     do {
     try fileManager.copyItem(atPath: Bundle.main.path(forResource: "pages", ofType: "csv")!, toPath: (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String])[0])
     }
     catch let error as NSError {
     print("Ooops! Something went wrong: \(error)")
     }
     */
    
    
    
    guard let pageListFileLocation = Bundle.main.path(forResource: pageListFile, ofType: "csv") else { return [] }
    
    let fileManager = FileManager.default
    let documentDirectory = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as [String])[0] as String
    
    //var filePath:String? = nil
    var fileNamePostfix = 0
    //let filePath = "\(documentsDirectory)/\pages.csv"
    
    var contentsPath :String?
    do {
        let fileList = try fileManager.contentsOfDirectory(atPath: documentDirectory) as [String]
        for single in fileList {
            if (single.range(of: "contents") != nil ) {
                print("have it!!")
                contentsPath = documentDirectory + "/" + single
                //print(contentsPath)
            } else {
                print("do not have contents file")
            }
        }
        print(fileList)
    } catch {
        print("something is wrong")
    }
    
    var tempContentFileLocation :String?
    
    if (contentsPath != nil ) {
        tempContentFileLocation = contentsPath
    } else {
        tempContentFileLocation = Bundle.main.path(forResource: contentFile, ofType: "csv")
    }
    
    let contentFileLocation = tempContentFileLocation!
    
    //guard let tempContentFileLocation = contentsPath else {return []} //Bundle.main.path(forResource: contentFile, ofType: "csv") else { return [] }
    
    do {
        let pageData = (try String(contentsOfFile: pageListFileLocation, encoding: String.Encoding.utf8)).csvRows()
        let contentData = (try String(contentsOfFile: contentFileLocation, encoding: String.Encoding.utf8)).csvRows()
        
        for pageIndex in 0..<pageData.count where pageIndex != 0 {
            
            if (pageData[pageIndex][0] == "") {
                continue
            }
            
            var currentContent :[[String]] = []
            
            for contentIndex in 0..<contentData.count where contentIndex != 0 {
                if ( contentData[contentIndex][2] == pageData[pageIndex][1] ) {
                    currentContent.append( contentData[contentIndex] )
                }
            }
            
            
            let pageTitle = pageData[pageIndex][7].trimmed() != "" ? pageData[pageIndex][7] : pageData[pageIndex][0]
            let dominance = pageData[pageIndex][6].lowercased() == "yes" ? true : false
            
            let isActivated = { () -> Bool in
                let single = pageData[pageIndex]
                let pageName = single[0]
                let varList = parseForVariables(single[2])
                let plusTriggerStr = single[2]
                let pageDepenency = single[3].components(separatedBy: "|")
                
                
                
     
                var positively_triggered = false
                
                //print(plusTriggerStr)
                
                if plusTriggerStr == "" {
                    positively_triggered = true
                } else {
                    positively_triggered = false
                    let targetVariables :[String:Double] = extractDoubleDictFromVariableNames(variables: varList)
                    
                    
                    /*for singleVar in varList {
                     
                     if( targetVariables[singleVar] == nil  && Global.classStatusInt[singleVar] != nil)  {
                     targetVariables[singleVar] = Double(Global.classStatusInt[singleVar]!)
                     } else {
                     targetVariables[singleVar] = Global.classStatusDouble[singleVar]
                     }
                     }*/
                    
                    positively_triggered = NSPredicate(format: getTriggerString(plusTriggerStr)).evaluate(with: targetVariables)
                }
                
                // denpendency 확인
                
                for singleDepen in pageDepenency {
                    if( singleDepen.trimmingCharacters(in: NSCharacterSet.whitespaces) != "" && Global.classStatusDouble[singleDepen] == nil && Global.classStatusInt[singleDepen] == nil  ) {
                        positively_triggered = false
                    }
                }
                
                //print(positively_triggered)
                return positively_triggered
                
            }
            
            let pageBuildClosure = { () -> [PageItem] in
                var items = PageItemContainer() //:[PageItem] = []
                
                var variableDescriptionNames :[String:String] = [:]
                var variableDescription :[String:String] = [:]
                
                if let variableDescriptionCSVLocation = Bundle.main.path(forResource: variableDescriptionFile, ofType: "csv") {
                    do {
                        let csvData = try String(contentsOfFile: variableDescriptionCSVLocation)
                        let csv = csvData.csvRows()
                        for index in 0..<csv.count where index != 0{
                            let single = csv[index]
                            let type = single[2]
                            let id = single[1]
                            let name = single[0]
                            let unit = single[4]
                            
                            
                            variableDescriptionNames[id] = name
                            
                            switch( type ) {
                            case "CATEGORY":
                                var values = single[3].components(separatedBy: "|")
                                
                                
                                if let givenIndex = Global.classStatusInt[id] {
                                    let descriptionStr = values[ givenIndex ]
                                    
                                    variableDescription[id] = descriptionStr
                                    
                                }
                                
                            case "NUMERIC":
                                
                                if let num = Global.classStatusDouble[id]  {
                                    variableDescription[id] = String(num) +  " " + unit
                                    
                                } else {
                                    variableDescription[id]  = "Not Available"
                                }
                                
                            default:
                                break
                            }
                        }
                        
                    } catch {
                        print (error)
                    }
                }
                
                
                let currentPage = pageData[pageIndex]
                let notables = currentPage[4].components(separatedBy: "|")
                
                for singleInputReviewID in notables {
                    if( singleInputReviewID != "") {
                        
                        let notableTitle = variableDescriptionNames[singleInputReviewID.trimmingCharacters(in: .whitespacesAndNewlines)]
                        let notableContent = variableDescription[singleInputReviewID.trimmingCharacters(in: .whitespacesAndNewlines)]
                        
                        if (notableTitle != nil && notableContent != nil ) {
                            items.addHighPriorityItem( PageNotableControl(title: notableTitle!, contentBuilder: { return notableContent! }, getVisibility: { true }, tag: ItemTag.Both.rawValue  )  )
                        }
                        
                    }
                }
                
                let seeAlso = currentPage[5].components(separatedBy: "|")
                for singleSeeAlsoID in seeAlso {
                    let id = singleSeeAlsoID.trimmingCharacters(in: .whitespacesAndNewlines)
                    if ( id != "" ) {
                        let reusableItem = reusableManager.getReusableAlternative(id: id)
                        if (reusableItem != nil) {
                            items.addSeeAlso( reusableItem! )
                        }
                    }
                }
                
                //var firstNotable = true
                
                var affectsTo :[String:String] = [:]
                var allVarsInterest :[(String, [String])] = []
                
            
                for index in 0..<currentContent.count {
                    let single = currentContent[index]
                    let id = single[1]
                    let varsInterest = parseForVariables(single[6])
                    allVarsInterest.append(  (id, varsInterest) )
                }
                
                
                for index in 0..<currentContent.count {
                    let single = currentContent[index]
                    
                    let name = single[0]
                    let id = single[1]
                    let pageName = single[2]
                    let type = single[3]
                    let title = single[4]
                    let value = single[5]
                    let positive_trigger_formula = single[6]
                    //let itemCount = items.count
                    let secondaryValue = single[7]
                    let json_detail = single[8]
                    let target = single[9]
                    let varsInterest = parseForVariables(single[6])
                    
                    let negative_trigger = single[10]
                    let variableDependencyStr = single[11]
                    let UIdependency = single[12]
                    let callout_name = single[13]
                    let callout_title = single[14]
                    let callout_text = single[15]
                    let callout_reference = single[16]
                    let callout_json = single[17]
                    
                    /*
                     var segmentActions :[ () -> Void ] = []
                     //Global.classStatusInt[target] = -1 // 초기화
                     for (index, item) in items.enumerated() {
                     segmentActions.append( { Global.classStatusInt[target] = index; print ( Global.classStatusInt[target] )}  )
                     }
                     
                     let segmentDeselectAction :( () -> Void ) = { Global.classStatusInt[target] = nil }
                     let injector :( () -> Int? ) = { return Global.classStatusInt[target] }
                     */
                    
                    switch( type ) {
                    case "SUMMARY":
                        //items.append( PageSummaryItem( title: "Noncardiac", content: value  )  )
                        var text = value
              
                        
                        var richText = buildRichText(text: text)
                        
                        items.addTopItem(PageSummaryItem(title: title, contentBuilder: {return richText}, getVisibility: {
                            
                            // 해당 배리어블에 어떤 값이 존재하는가?
                            let varDependency = true
                            var positively_triggered = false
                            
                            let varsInterest :[String] = parseForVariables(positive_trigger_formula)
                            
                            if positive_trigger_formula == "" {
                                positively_triggered = true
                            } else {
                                positively_triggered = false
                                let targetVariables = extractDoubleDictFromVariableNames(variables: varsInterest)
                                
                                positively_triggered = NSPredicate(format:  getTriggerString( positive_trigger_formula )).evaluate(with: targetVariables)
                                
                            }
                            
                            return varDependency && positively_triggered
                            
                        }, tag: nil) )

                        
                    case "NOTABLE":

                        
                        if let str = variableDescription[value] {
                            items.addHighPriorityItem(PageNotableControl(title: title, contentBuilder: { return str }, getVisibility: { true }, tag: ItemTag.Both.rawValue  ) )
                        }
                        
                        break
                        
                    case "TEXT":
                        
                        let strSentences = value.components(separatedBy: "))")
                        var statements :[Statement] = []
                        
                        for singleStr in strSentences {
                            if( singleStr.components(separatedBy: "((").count < 2 ) {
                                
                                let statementsBuilt = buildRichStatements(text: (singleStr.components(separatedBy: "(("))[0])
                                
                                statements = statements + statementsBuilt
                                
                            } else {
                                let refStr = (singleStr.components(separatedBy: "(("))[1]
                                
                                let statementsBuilt = buildRichStatements(text: (singleStr.components(separatedBy: "(("))[0])
                                
                                for singleRef in parseReferences(refStr) {
                                    statementsBuilt.last!.addReference( num: singleRef )
                                }
                                statements = statements + statementsBuilt
                            }
                            
                        }
                        
                        items.addItem(Paragraph(title: id, isAppearing: {
                            
                            // 해당 배리어블에 어떤 값이 존재하는가?
                            let varDependency = determineDependency(parsingStr: variableDependencyStr)
                            var positively_triggered = determineTrigger(triggeringStr: positive_trigger_formula)
                            
                            
                            return varDependency && positively_triggered
                            
                        }, build: {(p) in
                            
                            if (title.trimmed() != "") { p.addHeading(title); p.enter() }
                            for statement in statements {
                                p.addStatement(statement: statement)
                            }
                            
                            if(  callout_name != "" && callout_title != "" && callout_text != "" ) {
                                let paragraph = Paragraph(title: callout_title, withString: callout_text, references: parseReferences(callout_reference))
                                paragraph.title_short = callout_name
                                p.addComment(paragraph)
                            }
                            
                            
                        }, className: id))
                        
                    case "SEGMENTAL":
                        let varDependency = determineDependency(parsingStr: variableDependencyStr)
                        var positively_triggered = determineTrigger(triggeringStr: positive_trigger_formula)
                        let references = parseReferences( callout_reference )
                        
                        let whatParagraph :Paragraph? = callout_title != "" ?  Paragraph(title: callout_title, withString: callout_text, references: references ) : nil
                        
                        let whatName :String? = callout_title != "" ? callout_title : nil
                        
                        var rearrangedItems :[String] = []
                        let segItems = value.trimmed().components(separatedBy: "|")
                        let items_subtitles = secondaryValue == "" ? rearrangedItems : secondaryValue.trimmed().components(separatedBy: "|")
                        
                        
                        for (index, item) in segItems.enumerated() {
                            
                            // 셀렉션에서 빈칸 제거함
                            let currentItem = item.trimmed()
                            if (currentItem.last == "!" && Global.classStatusInt[target] == nil) {
                                Global.classStatusInt[target] = index
                                rearrangedItems.append(String(currentItem.replacingOccurrences(of: "!", with: "")))
                                
                            } else {
                                rearrangedItems.append(currentItem)
                            }
                        }
                        
                        var segmentActions :[ () -> Void ] = []
                        
                        for (index, item) in segItems.enumerated() {
                            segmentActions.append( { Global.classStatusInt[target] = index;}  )
                        }
                        
                        let segmentDeselectAction :( () -> Void ) = { Global.classStatusInt[target] = nil }
                        let injector :( () -> Int? ) = { return Global.classStatusInt[target] }
                        
                        var affectsTo :[String] = []
                        for singleVarCollection in allVarsInterest {
                            if( singleVarCollection.1.contains( target ) ) {
                                affectsTo.append(singleVarCollection.0)
                            }
                        }
                        
                        let segItem = PageRichSegmentedControl(title: title, param: Parameter.NONE, paramName: "NONE", items: rearrangedItems, segmentActions: segmentActions, defaultSubtitle: "Not Selected", subtitles: items_subtitles, whatName: whatName, whatParagraph: whatParagraph, injector: injector, deselectAction: segmentDeselectAction, cellConfiguration: { _ in }, isAppearing: {
                            
                            // 해당 배리어블에 어떤 값이 존재하는가?
                            let varDependency = determineDependency(parsingStr: variableDependencyStr)
                            let positively_triggered = determineTrigger(triggeringStr: positive_trigger_formula)
                            
                            return varDependency && positively_triggered
                            
                        }, affectsTo: affectsTo, className: id )
                        
                        /*
                        if (why != "" ) {
                            segItem.why = why
                        }*/
                        
                        items.addItem(segItem)
                        
                        
                        break
                        
                    case "PARAGRAPH":
                        let data: Data = (json_detail as String?)!.data(using: String.Encoding.utf8)!
                        
                        if (json_detail == "") {
                            
                            
                            items.addItem(Paragraph(title: id, isAppearing: {
                                
                                // 해당 배리어블에 어떤 값이 존재하는가?
                                var varDependency = true
                                var positively_triggered = false
                                
                                var varsInterest :[String] = parseForVariables(positive_trigger_formula)
                                
                                if positive_trigger_formula == "" {
                                    positively_triggered = true
                                } else {
                                    positively_triggered = false
                                    var targetVariables = extractDoubleDictFromVariableNames(variables: varsInterest)
                                    
                                    positively_triggered = NSPredicate(format:  getTriggerString( positive_trigger_formula )).evaluate(with: targetVariables)
                                    
                                }
                                
                                return varDependency && positively_triggered
                                
                            }, build: {(p) in
                                if let paragraphItemCSVLocation = Bundle.main.path(forResource: paragraphItemFile, ofType: "csv") {
                                    do {
                                        let csvData = try String(contentsOfFile: paragraphItemCSVLocation)
                                        let csv = csvData.csvRows()
                                        var itemCount = 0
                                        
                                        for index in 0..<csv.count where index != 0{
                                            let single = csv[index]
                                            
                                            let paragraph_id = single[0]
                                            let item_type = single[1]
                                            let item_value = single[2]
                                            let references = parseReferences( single[3] )
                                            let varsInterest = parseForVariables( single[4] )
                                            let positive_trigger_formula = single[4]
                                            let variableDependencyStr = single[5]
                                            let item_comment_title = single[6]
                                            let item_comment_text = parseRichString(single[7])
                                            let item_comment_reference = parseReferences(single[8])
                                            
                                            let isAppearing = variableDependencyStr == "" && positive_trigger_formula == nil  ? nil : { () -> Bool in
                                                
                                                // 해당 배리어블에 어떤 값이 존재하는가?
                                                let varDependency = determineDependency(parsingStr: variableDependencyStr)
                                                var positively_triggered = determineTrigger(triggeringStr: positive_trigger_formula)
                                                
                                                return varDependency && positively_triggered
                                                
                                            }
                                            
                                            if (paragraph_id != id ) { continue }
                                            
                                            switch( item_type ) {
                                            case "HEADING":
                                                p.enter()
                                                p.addHeading( item_value )
                                                p.enter()
                                                itemCount+=1
                                            case "SENTENCE":
                                                
                                                //var statements :[Statement] = []
                                                
                                                let compo = item_value.components(separatedBy: "]]")
                                                for single in compo {
                                                    let spt = single.components(separatedBy: "[[")
                                                    if (spt.count == 2) {
                                                        
                                                        p.addStatement( spt[0], isAppearing: isAppearing )
                                        
                                                        
                                                        if  let linkedSt = reusableManager.getReusable(id: spt[1] )  {
                                                            
                                                            linkedSt.isAppearing = isAppearing != nil ? isAppearing! : linkedSt.isAppearing
                                                            
                                                            p.addStatement( statement: linkedSt)
                                                        } else if let numStr = getPredeterminedValue(id: spt[1]) {
                                                            
                                                            let tempStatement = Statement(content: numStr)
                                                            tempStatement.isAppearing = isAppearing != nil ? isAppearing! : tempStatement.isAppearing
                                                            p.addStatement(statement: tempStatement)
                                                        } else if let numStr = getFormulaValue(id: spt[1]) {
                                                            let tempStatement = Statement(content: numStr)
                                                            tempStatement.isAppearing = isAppearing != nil ? isAppearing! : tempStatement.isAppearing
                                                            p.addStatement(statement: tempStatement)
                                                        } else if let comment = reusableManager.getReusableComment(id: spt[1]) {
                                                            let tempStatement = Statement(content: "")
                                                            tempStatement.isAppearing = isAppearing != nil ? isAppearing! : tempStatement.isAppearing
                                                            tempStatement.comment = comment
                                                            p.addStatement(statement: tempStatement)
                                                        }
                                                        
                                                    } else {
                                                        p.addStatement( spt[0] )
                                                    }
                                                }
                                                
                                                if (references.count > 0 ) {
                                                    p.addStatement( "" , references: references  )
                                                }
                                                
                                                itemCount+=1
                                            case "REUSABLE":
                                                p.addStatement(statement: reusableManager.getReusable(id: item_value ))
                                                itemCount+=1
                                            case "ENTER":
                                                p.enter()
                                                itemCount+=1
                                            case "LINKED":
                                                p.addLinkedStatement(item_value, comment: Paragraph(title: item_comment_title, withString: item_comment_text, references: item_comment_reference) )
                                                itemCount+=1
                                            case "COMMENT":
                                                
                                                let paragraph = Paragraph(title: item_comment_title, withString: item_comment_text, references: item_comment_reference)
                                                paragraph.title_short = item_value
                                                
                                                p.addComment(paragraph)
                                                itemCount+=1
                                            default:
                                                break
                                            }
                                        }
                                        
                                        if (itemCount == 0 || value != "" ) {
                                            p.addStatement( value )
                                        }
                                        
                                    } catch {
                                        print (error)
                                    }
                                    
                                    
                                }
                                
                            }))
                            
                            
                            
                        } else {
                            
                            let json_serialized = try? JSONSerialization.jsonObject(with: data, options: [])
                            items.addItem( Paragraph(title: id, isAppearing: { true }, build: {(p) in
                                
                                if let dictionary = json_serialized as? [String: Any] {
                                    
                                    let elementList = dictionary["elements"] as! NSArray?
                                    if let array = elementList as? [Dictionary<String, Any>] {
                                        
                                        for single in array {
                                            
                                            if let type = single["type"] as? String {
                                                switch(type) {
                                                case "heading":
                                                    p.addHeading(single["text"] as! String)
                                                case "sentence":
                                                    if let refNum = single["reference"] as? Int {
                                                        p.addStatement(single["text"] as! String, references: [refNum])
                                                    } else {
                                                        p.addStatement(single["text"] as! String)
                                                    }
                                                    
                                                case "enter":
                                                    p.enter()
                                                case "reusable":
                                                    p.addStatement(statement: reusableManager.getReusable(id: single["target"] as! String ))
                                                    
                                                default:
                                                    break
                                                }
                                            } else {
                                                continue
                                            }
                                            
                                            
                                        }
                                        
                                    }
                                    //
                                }
                                
                                
                                
                            }))
                        }
                        
                    default:
                        print("somethine else")
                    }
                    
                }
                
                return items.produce()
            }
            
            let page = Page(withDesign: PageDesign(build: pageBuildClosure, pageTitle: pageTitle, isActivated: isActivated ))
            page.isDominant = dominance
            
            pages.append( page )
            
        }
        
        
        
    } catch {
        print (error)
    }
    
    return pages
    
    
    /*
     
     let pageBuildClosure = { (g) -> [PageItem] in
     
     var items :[PageItem] = []
     var variableDescription :[String:String] = [:]
     
     if let variableDescriptionCSVLocation = Bundle.main.path(forResource: "variableDescription", ofType: "csv") {
     do {
     let csvData = try String(contentsOfFile: variableDescriptionCSVLocation)
     let csv = csvData.csvRows()
     for index in 0..<csv.count where index != 0{
     let single = csv[index]
     let type = single[2]
     let id = single[1]
     let name = single[0]
     
     
     switch( type ) {
     case "CATEGORY":
     var values = single[3].components(separatedBy: "|")
     
     
     if let givenIndex = Global.classStatusInt[id] {
     let descriptionStr = values[ givenIndex ]
     
     variableDescription[id] = descriptionStr
     
     }
     
     default:
     break
     }
     }
     
     } catch {
     print (error)
     }
     }
     
     
     if let dashboardCSVLocation = Bundle.main.path(forResource: "contents", ofType: "csv") {
     do {
     let csvData = try String(contentsOfFile: dashboardCSVLocation)
     let csv = csvData.csvRows()
     for index in 0..<csv.count where index != 0{
     
     let single = csv[index]
     
     let name = single[0]
     let id = single[1]
     let pageName = single[2]
     let type = single[3]
     let title = single[4]
     let value = single[5]
     let secondaryValue = single[6]
     let json_detail = single[7]
     let target = single[9]
     let varsInterest = single[8].components(separatedBy: "|")
     let positive_trigger_formula = single[10]
     let negative_trigger = single[11]
     let variableDependencyStr = single[12]
     let UIdependency = single[13]
     let callout_name = single[14]
     let callout_title = single[15]
     let callout_text = single[16]
     let callout_reference = single[17]
     let callout_json = single[18]
     
     switch( type ) {
     case "SUMMARY":
     items.append( PageSummaryItem( title: "Noncardiac", content: value  )  )
     
     case "NOTABLE":
     if let str = variableDescription[target] {
     items.append( PageNotableControl(title: title, contentBuilder: { return str }, getVisibility: { true }, tag: ItemTag.Both.rawValue  ) )
     }
     
     break
     
     case "PARAGRAPH":
     let data: Data = (json_detail as String?)!.data(using: String.Encoding.utf8)!
     let json_serialized = try? JSONSerialization.jsonObject(with: data, options: [])
     
     
     items.append( Paragraph(title: "LowRiskProceedWithSurgery ", isAppearing: { true }, build: {(p) in
     
     if let dictionary = json_serialized as? [String: Any] {
     
     let elementList = dictionary["elements"] as! NSArray?
     if let array = elementList as? [Dictionary<String, Any>] {
     
     for single in array {
     let type = single["type"] as! String
     
     switch(type) {
     case "heading":
     p.addHeading(single["text"] as! String)
     case "sentence":
     if let refNum = single["reference"] as? Int {
     p.addStatement(single["text"] as! String, references: [refNum])
     } else {
     p.addStatement(single["text"] as! String)
     }
     
     case "enter":
     p.enter()
     case "reusable":
     p.addStatement(statement: getReusable(id: single["target"] as! String ))
     
     default:
     break
     }
     }
     
     }
     }
     
     
     
     }))
     
     
     default:
     print("somethine else")
     }
     }
     } catch {
     print(error)
     }
     }
     
     return items
     
     }
     
     */
    //guard let pageListData = String(contentsOfFile: pageListFileLocation)
    
    
    
    print( pageListFileLocation )
    
    
    /*if let variableDescriptionCSVLocation = Bundle.main.path(forResource: "variableDescription", ofType: "csv") {
     do {
     let csvData = try String(contentsOfFile: variableDescriptionCSVLocation)
     let csv = csvData.csvRows()
     for index in 0..<csv.count where index != 0{
     let single = csv[index]
     let type = single[2]
     let id = single[1]
     let name = single[0]
     */
}



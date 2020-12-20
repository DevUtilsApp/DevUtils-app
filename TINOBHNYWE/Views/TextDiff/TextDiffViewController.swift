//
//  TextDiffViewController.swift
//  DevUtils
//
//  Created by Tony Dinh on 10/6/20.
//  Copyright © 2020 Tony Dinh. All rights reserved.
//

import Cocoa

class TextDiffViewController: ToolViewController, NSTextViewDelegate {
  @IBOutlet var input1TextView: NSTextView!
  @IBOutlet var input2TextView: NSTextView!
  @IBOutlet var diffTextView: NSTextView!
  @IBOutlet weak var diffModeCharacterCheckbox: NSButton!
  @IBOutlet weak var diffModeWordCheckbox: NSButton!
  @IBOutlet weak var diffModeLineCheckbox: NSButton!
  @IBOutlet weak var outputFormattedTextCheckbox: NSButton!
  @IBOutlet weak var outputHTMLCheckbox: NSButton!
  @IBOutlet weak var outputDiffCheckbox: NSButton!
  @IBOutlet weak var minimalDiffQuestionButton: NSButton!
  @IBOutlet weak var diffPrevButton: NSButton!
  @IBOutlet weak var diffNextButton: NSButton!
  @IBOutlet weak var diffCountLabel: NSTextField!
  
  let dmp = DiffMatchPatch()
  
  var diffRanges: [NSRange] = []
  var currentDiffRangesIndex = -1
  
  enum DiffMode {
    case characters
    case words
    case lines
  }
  
  enum OutputMode {
    case formattedText
    case HTML
    case diff
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    input1TextView.setupStandardTextview()
    input2TextView.setupStandardTextview()
    diffTextView.setupStandardTextview()
  }
  
  func getOutputMode() -> OutputMode {
    if (outputFormattedTextCheckbox.objectValue as? Bool ?? false) == true {
      return .formattedText
    }
    if (outputHTMLCheckbox.objectValue as? Bool ?? false) == true {
      return .HTML
    }
    if (outputDiffCheckbox.objectValue as? Bool ?? false) == true {
      return .diff
    }
    
    log.error("invalid output mode state")
    return .formattedText
  }
  
  @IBAction func outputCheckboxesActions(_ sender: NSButton) {
    outputFormattedTextCheckbox.objectValue = false
    outputHTMLCheckbox.objectValue = false
    outputDiffCheckbox.objectValue = false
    sender.objectValue = true
    if outputDiffCheckbox.objectValue as? Bool ?? false == true {
      minimalDiffQuestionButton.isHidden = false
    } else {
      minimalDiffQuestionButton.isHidden = true
    }
    refresh()
  }
  
  func getDiffMode() -> DiffMode {
    if (diffModeCharacterCheckbox.objectValue as? Bool ?? false) == true {
      return .characters
    }
    if (diffModeWordCheckbox.objectValue as? Bool ?? false) == true {
      return .words
    }
    if (diffModeLineCheckbox.objectValue as? Bool ?? false) == true {
      return .lines
    }
    
    log.error("invalid diff mode state")
    return .characters
  }
  
  @IBAction func diffModeCheckboxesActions(_ sender: NSButton) {
    diffModeCharacterCheckbox.objectValue = false
    diffModeWordCheckbox.objectValue = false
    diffModeLineCheckbox.objectValue = false
    sender.objectValue = true
    refresh()
  }
  
  
  func textDidChange(_ notification: Notification) {
    refresh()
  }
  
  func getDiff(_ input1: String, _ input2: String) -> NSMutableArray {
    if getDiffMode() == .characters {
      let diff = dmp.diff_main(ofOldString: input1, andNewString: input2)
      dmp.diff_cleanupSemantic(diff)
      return diff!
    }
/*
    if getDiffMode() == .words {
      let d3 = dmp.diff_wordsToChars(forFirstString: input1, andSecondString: input2)
      let diff = dmp.diff_main(ofOldString: (d3![0] as! String), andNewString: (d3![1] as! String))
      dmp.diff_chars((diff as! [Any]), toLines: (d3![2] as! [Any]))
      return diff!
    }
    
    if getDiffMode() == .lines {
      let d3 = dmp.diff_linesToChars(forFirstString: input1, andSecondString: input2)
      let diff = dmp.diff_main(ofOldString: (d3![0] as! String), andNewString: (d3![1] as! String))
      dmp.diff_chars((diff as! [Any]), toLines: (d3![2] as! [Any]))
      return diff!
    }
*/
    log.error("invalid diff mode state")
    return []
  }
  
  func refresh() {
    
    let d = getDiff(input1TextView.string, input2TextView.string)

    let s = NSMutableAttributedString()
    
    diffRanges = []
    currentDiffRangesIndex = -1
    
    var offset = 0
    
    if getOutputMode() == .formattedText {
      d.forEach({ (diff) in
        let item = diff as! Diff
        
        // TODO: this will not work well for strings with multi bytes characters
        // like emojis.
        let length = item.text.lengthOfBytes(using: .utf8)
        
        if item.operation == DIFF_DELETE {
          s.append(deletedAttrStr(content: item.text))
          diffRanges.append(.init(location: offset, length: length))
        } else if item.operation == DIFF_INSERT {
          s.append(addedAttrStr(content: item.text))
          diffRanges.append(.init(location: offset, length: length))
        } else if item.operation == DIFF_EQUAL {
          s.append(equalAttrStr(content: item.text))
        } else {
          log.error("diff-match-patch returned unexpected data")
        }
        
        offset += length
      })
    }
    
    updateNextPrevButtonState()
    // log.debug("diff ranges: \(diffRanges)")
    
    if getOutputMode() == .HTML {
      s.append(equalAttrStr(content: dmp.diff_prettyHtml(d)))
    }
    
    if getOutputMode() == .diff {
      s.append(equalAttrStr(content: dmp.patch_(toText: dmp.patch_make(fromDiffs: d))))
    }
    
    diffTextView.textStorage?.setAttributedString(s)
  }
  
  func updateNextPrevButtonState() {
    diffCountLabel.stringValue = "\(diffRanges.count)"
    
    if diffRanges.count > 0 {
      diffNextButton.isEnabled = true
      diffPrevButton.isEnabled = true
    } else {
      diffNextButton.isEnabled = false
      diffPrevButton.isEnabled = false
    }
    
  }
  
  @IBAction func diffPrevButtonAction(_ sender: Any) {
    if currentDiffRangesIndex > 0 {
      currentDiffRangesIndex -= 1
      updateNextPrevButtonState()
    }
    focusDiffRange()
  }
  
  @IBAction func diffNextButtonAction(_ sender: Any) {
    if currentDiffRangesIndex < diffRanges.count - 1 {
      currentDiffRangesIndex += 1
      updateNextPrevButtonState()
    }
    focusDiffRange()
  }
  
  func focusDiffRange() {
    // log.debug("currentDiffRangesIndex: \(currentDiffRangesIndex)")
    if let range = diffRanges[safe: currentDiffRangesIndex] {
      diffTextView.scrollRangeToVisible(range)
      diffTextView.showFindIndicator(for: range)
    }
  }
  
  func addedAttrStr(content: String) -> NSMutableAttributedString {
    var attributes = [
      NSAttributedString.Key.backgroundColor: NSColor.systemGreen as Any,
      NSAttributedString.Key.foregroundColor: NSColor.black as Any,
      NSAttributedString.Key.underlineStyle: 1 as Any
    ]
    if let menlo = NSFont(name: AppState.TEXTVIEW_MONO_FONT, size: 12) {
      attributes[NSAttributedString.Key.font] = menlo
    }
    return NSMutableAttributedString.init(string: content, attributes: attributes)
  }
  
  func deletedAttrStr(content: String) -> NSMutableAttributedString {
    var attributes = [
      NSAttributedString.Key.backgroundColor: NSColor.systemRed as Any,
      NSAttributedString.Key.foregroundColor: NSColor.black as Any,
      NSAttributedString.Key.strikethroughStyle: 1 as Any
    ]
    if let menlo = NSFont(name: AppState.TEXTVIEW_MONO_FONT, size: 12) {
      attributes[NSAttributedString.Key.font] = menlo
    }
    return NSMutableAttributedString.init(string: content, attributes: attributes)
  }
  
  func equalAttrStr(content: String) -> NSMutableAttributedString {
    var attributes = [NSAttributedString.Key.foregroundColor: NSColor.textColor as Any]
    if let menlo = NSFont(name: AppState.TEXTVIEW_MONO_FONT, size: 12) {
      attributes[NSAttributedString.Key.font] = menlo
    }
    return NSMutableAttributedString.init(string: content, attributes: attributes)
  }
  
  @IBAction func copyButtonAction(_ sender: Any) {
    diffTextView.copyToClipboardFormatted()
  }
  
  @IBAction func input1ClipboardButtonAction(_ sender: Any) {
    input1TextView.setStringRetrainUndo(NSPasteboard.general.string(forType: .string) ?? "")
    refresh()
  }
  
  @IBAction func input1ClearButtonAction(_ sender: Any) {
    input1TextView.setStringRetrainUndo("")
    refresh()
  }
  
  @IBAction func input2ClipboardButtonAction(_ sender: Any) {
    input2TextView.setStringRetrainUndo(NSPasteboard.general.string(forType: .string) ?? "")
    refresh()
  }
  
  @IBAction func input2ClearButtonAction(_ sender: Any) {
    input2TextView.setStringRetrainUndo("")
    refresh()
  }
  
  @IBAction func sampleButtonAction(_ sender: Any) {
    input1TextView.setStringRetrainUndo("""
    if (param == ISCSI_PARAM_LOCAL_PORT)
        rc = kernel_getsockname(tcp_sw_conn->sock,
                    (struct sockaddr *)&addr);
    else
        rc = kernel_getpeername(tcp_sw_conn->sock,
                    (struct sockaddr *)&addr);
    spin_unlock_bh(&conn->session->frwd_lock);
    if (rc < 0)
        return rc;
    """)
    input2TextView.setStringRetrainUndo("""
    sock = tcp_sw_conn->sock;
    sock_hold(sock->sk);
    spin_unlock_bh(&conn->session->frwd_lock);

    if (param == ISCSI_PARAM_LOCAL_PORT)
        rc = kernel_getsockname(sock,
                    (struct sockaddr *)&addr);
    else
        rc2 = kernel_getpeername(sock,
                    (struct sockaddr *)&addr);
    sock_put(sock->sk);
    if (rc < 0)
        return rc;
    """)
    refresh()
  }
  
  @IBAction func minimalDiffLabelAction(_ sender: Any) {
    GeneralHelpers.alert(title: "Minimal Diff Format", text: "The Minimal Diff format is similar to Unidiff with some differences. Other applications may not be able to parse it.\n\nSee https://github.com/google/diff-match-patch/wiki/Unidiff for more details.")
  }
  
  @IBAction func swapInputsButton(_ sender: Any) {
    let temp = input2TextView.string
    input2TextView.setStringRetrainUndo(input1TextView.string)
    input1TextView.setStringRetrainUndo(temp)
  }
}

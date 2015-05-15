//
//  ChatViewController.swift
//  
//
//  Created by Frank Jiang on 28/4/15.
//
//

import UIKit
import SwiftyJSON

enum SlideOutState {
    case Normal
    case LeftPanelExpanded
}

class ChatViewController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate {

    var users:[String] = []
    var convos:[String: String] = ["ffjiang": "FRANK SAYS HI", "dxyang": "DAN SAYS HI", "vibhaa": "VIBHAA SAYS HI", "ac17": "ANGELICA SAYS HI", "arturf": "ARTUR SAYS HI"]
    
    var textEntry: ChatEntryTextView!
    var chatTextView: UITextView!
    var sendButton: UIButton!
    
    var keyboardIsShown: Bool = false
    
    var sidePanelCurrentlySelectedUser: String?
    
    var currentState: SlideOutState = .Normal {
        didSet {
            let shouldShowShadow = currentState != .Normal
            showShadowForMainViewController(shouldShowShadow)
        }
    }
    var leftViewController: SidePanelViewController?
    
    var mainPanelExpandedOffset: CGFloat = 150
    
    var openSidePanelRecognizer: UISwipeGestureRecognizer!
    var closeSidePanelRecognizer: UISwipeGestureRecognizer!
    
    var backgroundView: UIImageView?
    var topView: UIImageView?
    var bottomView: UIImageView?
    
    var websiteURLbase = ""
    var appNetid = ""
    var pwHash = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        websiteURLbase = appDelegate.websiteURLBase
        appNetid = appDelegate.userNetid
        pwHash = appDelegate.pwHash
    
        (self.view as! ChatView).viewController = self
        
        (self.view as! ChatView).scrollEnabled = true
        
        self.automaticallyAdjustsScrollViewInsets = false
        (self.view as! ChatView).contentInset = UIEdgeInsetsMake(0, 0, 49, 0)
        
        // Set background color to dark blue. Create top and bottom views
        // so that when you scroll, everything is still blue
        backgroundView = UIImageView(image: UIImage(named: "darkbluebackground.png"))
        topView = UIImageView(image: UIImage(named: "darkbluebackground.png"))
        bottomView = UIImageView(image: UIImage(named: "darkbluebackground.png"))
        backgroundView!.frame = UIScreen.mainScreen().bounds
        topView!.frame = CGRectMake(0, -500, self.view.frame.size.width + 50, 500)
        bottomView!.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width + 50, 500)
        self.view.insertSubview(backgroundView!, atIndex: 0)
        self.view.insertSubview(topView!, atIndex: 0)
        self.view.insertSubview(bottomView!, atIndex: 0)
        
        textEntry = ChatEntryTextView()
        textEntry.delegate = self
        textEntry.becomeFirstResponder()
        textEntry.scrollEnabled = false
        textEntry.frame = CGRectMake(16.0, UIScreen.mainScreen().bounds.height - self.tabBarController!.tabBar.frame.size.height - 40, UIScreen.mainScreen().bounds.width - 80.0, 30.0)
        textEntry.layer.borderWidth = 0.5
        textEntry.layer.borderColor = UIColor.grayColor().CGColor
        textEntry.layer.cornerRadius = 5.0
        self.view.addSubview(textEntry)
        
        chatTextView = UITextView()
        chatTextView.delegate = self
        chatTextView.frame = CGRectMake(16.0, 75.0, UIScreen.mainScreen().bounds.width - 32.0, textEntry.frame.origin.y - 15.0 - 75.0)
        chatTextView.layer.borderWidth = 1.0
        chatTextView.layer.borderColor = UIColor.grayColor().CGColor
        chatTextView.layer.cornerRadius = 5.0
        chatTextView.editable = false
        self.view.addSubview(chatTextView)

        sendButton = UIButton.buttonWithType(UIButtonType.System) as! UIButton
        sendButton.setTitle("Send", forState: UIControlState.Normal)
        sendButton.frame = CGRectMake(UIScreen.mainScreen().bounds.width - 56.0, UIScreen.mainScreen().bounds.height - self.tabBarController!.tabBar.frame.size.height - 40, 40.0, 30.0)
        sendButton.addTarget(self, action: "sendMessage:", forControlEvents: UIControlEvents.TouchUpInside)
        sendButton.enabled = false
        self.view.addSubview(sendButton)
        
        openSidePanelRecognizer = UISwipeGestureRecognizer(target: self, action: "openLeftPanel:")
        self.view.addGestureRecognizer(openSidePanelRecognizer)
        
        closeSidePanelRecognizer = UISwipeGestureRecognizer(target: self, action: "closeLeftPanel:")
        closeSidePanelRecognizer.direction = UISwipeGestureRecognizerDirection.Left
        self.view.addGestureRecognizer(closeSidePanelRecognizer)
        
        // Find users
        let url = NSURL(string: self.websiteURLbase + "/mobileChatRetrieval.php?user2=" + appNetid + "&user1=" + appNetid + "&pwHash1=" + pwHash)
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            let json = JSON(data:data)
            var index = 0
            for (informationExchange:String, subJson: JSON) in json {
                var userFromString = json[index]["User_From"].string
                var userToString = json[index]["User_To"].string
                
                if userFromString! != self.appNetid {
                    if !contains(self.users, userFromString!) {
                        self.users.append(userFromString!)
                    }
                } else if userToString! != self.appNetid {
                    if !contains(self.users, userToString!) {
                        self.users.append(userToString!)
                    }
                }
                    
                index++
            }
        }
        task.resume()
        
        
        // Recognise keyboard appearing and disappearing
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: self.view.window)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: self.view.window)
        
        // Set the content size to be larger than the scrollsize, so there is a scrollbar
        var scrollContentSize: CGSize = UIScreen.mainScreen().bounds.size
        //(self.view as! ChatView).contentSize = scrollContentSize
        
        // Poll for new convos
        var timer = NSTimer.scheduledTimerWithTimeInterval(2.5, target: self, selector: "loadConversation:", userInfo: nil, repeats: true)
    }
    
    func keyboardWillHide(notification: NSNotification) {
        // Get the size of the keyboard
        if !self.keyboardIsShown || currentState == .LeftPanelExpanded {
            return
        }
        if let userInfo = notification.userInfo {
            if let keyboardSize = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
                
                var currentOffset: CGPoint = (self.view as! ChatView).contentOffset
                currentOffset.y -= keyboardSize.height - self.tabBarController!.tabBar.frame.size.height
                UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                    (self.view as! ChatView).contentOffset = currentOffset
                    }, completion: nil)
            }
            
        }
        self.keyboardIsShown = false
    }
    
    func keyboardWillShow(notification: NSNotification) {
        // To ensure we don't resize if the keyboard is already shown
        if self.keyboardIsShown {
            return
        }
        
        // Get the size of the keyboard
        if let userInfo = notification.userInfo {
            if let keyboardSize = (userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
                
                var currentOffset: CGPoint = (self.view as! ChatView).contentOffset
                currentOffset.y += keyboardSize.height - self.tabBarController!.tabBar.frame.size.height
                UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                    (self.view as! ChatView).contentOffset = currentOffset
                    }, completion: nil)
            }
            
        }
        self.keyboardIsShown = true
        
    }

    // TODO: doesn't seem to be working
    // dismisses iOS keyboard after you open a textfield and touch anywhere else
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        view.endEditing(true)
        super.touchesBegan(touches, withEvent: event)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func sendMessage(sender: AnyObject) {
        
        if let user = sidePanelCurrentlySelectedUser {
            var message = textEntry.text
            textEntry.text = ""
            
            if count(chatTextView.text) > 0 {
                chatTextView.text = chatTextView.text + appNetid + ": " + message + "\n"
            } else {
                chatTextView.text = message
            }
            
            textEntry.frame = CGRectMake(16.0, UIScreen.mainScreen().bounds.height - self.tabBarController!.tabBar.frame.size.height - 40, UIScreen.mainScreen().bounds.width - 80.0, 30.0)
            chatTextView.frame = CGRectMake(16.0, 75.0, UIScreen.mainScreen().bounds.width - 32.0, textEntry.frame.origin.y - 15.0 - 75.0)
            chatTextView.scrollRangeToVisible(NSMakeRange(count(chatTextView.text) - 1, 0))
            
            message = message.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())
            
            let url = NSURL(string: self.websiteURLbase + "/mobileChatUpload.php?to_user=" + user + "&from_user=" + appNetid + "&pwHash1=" + pwHash + "&msg=" + message)
            let task = NSURLSession.sharedSession().dataTaskWithURL(url!, completionHandler: nil)
            task.resume()
        }
    }

    // Adjusts the size of the two text views (the place where the user enters text, 
    // and the place showing the conversation), as the user enters text.
    func textViewDidChange(textView: UITextView) {
        var correctSize = textView.sizeThatFits(CGSizeMake(textView.frame.size.width, CGFloat.max))
        var heightDiff = correctSize.height - textEntry.frame.size.height
        textEntry.frame.size.height = correctSize.height
        textEntry.frame.origin.y = textEntry.frame.origin.y - heightDiff
        
        chatTextView.frame.origin.y -= heightDiff
        chatTextView.scrollRangeToVisible(NSMakeRange(count(chatTextView.text) - 1, 0))
        
        //(self.view as! ChatView).contentSize.height = textEntry.frame.size.height + chatTextView.frame.size.height
        
        
        if count(textView.text) > 0 {
            sendButton.enabled = true
        } else {
            sendButton.enabled = false
        }
    }
    
    // Toggles whether the left side panel with the list of users that you are
    // cahtting with is expanded or not
    func openLeftPanel(gesture: UIGestureRecognizer) {
        if currentState == .Normal {
            addLeftPanelViewController()
            animateLeftPanel(shouldExpand: true)
            self.view.endEditing(true)
            self.keyboardIsShown = false
        }
    }
        
    func closeLeftPanel(gesture: UIGestureRecognizer) {
        if currentState == .LeftPanelExpanded {
            animateLeftPanel(shouldExpand: false)
        }
        self.view.endEditing(true)
        self.keyboardIsShown = false
    }
    
    func addLeftPanelViewController() {
        if leftViewController == nil {
            leftViewController = SidePanelViewController()
            leftViewController!.users = self.users
        }
        self.addChildViewController(leftViewController!)
        leftViewController?.didMoveToParentViewController(self)
        self.view.addSubview(leftViewController!.view)
    }
    
    func animateLeftPanel(#shouldExpand: Bool) {
        if shouldExpand {
            currentState = .LeftPanelExpanded
            
            // Animate the main panel
            animateMainPanelXPosition(targetPosition: CGRectGetWidth(self.view.frame) - mainPanelExpandedOffset)
        } else {
            animateMainPanelXPosition(targetPosition: 0) { finished in
                self.currentState = .Normal
                self.leftViewController!.view.removeFromSuperview()
                self.leftViewController = nil
            }
        }
    }
    
    func animateMainPanelXPosition(#targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.view.frame.origin.x = targetPosition
        }, completion: completion)
    }
    
    @IBAction func leaveChatScreen() {
        var tabBarController = self.tabBarController as! TabBarViewController
        self.tabBarController!.selectedIndex = tabBarController.lastScreen
    }
    
    func loadConversation(sender: AnyObject) {
        if let user = sidePanelCurrentlySelectedUser {
            if !contains(users, user) {
                users.append(user)
            }
            
            let url = NSURL(string: self.websiteURLbase + "/mobileChatRetrieval.php?user2=" + user + "&user1=" + appNetid + "&pwHash1=" + pwHash)
            
            let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
                let json = JSON(data:data)
                
                var chatText = ""
                
                var index = 0
                for (informationExchange:String, subJson: JSON) in json {
                    var userString = json[index]["User_From"].string
                    var conversationString = json[index]["Conversation"].string
                    
                    chatText += userString! + ": " + conversationString! + "\n"
                    
                    index++
                }
                dispatch_async(dispatch_get_main_queue()) {
                    if chatText != self.chatTextView.text {
                        self.chatTextView.text = chatText
                        self.chatTextView.scrollRangeToVisible(NSMakeRange(count(self.chatTextView.text) - 1, 0))
                    }
                }
                
            }
            task.resume()

        }
    }
    
    func showShadowForMainViewController(shouldShowShadow: Bool) {
        if shouldShowShadow {
            self.view.layer.shadowOpacity = 0.8
        } else {
            self.view.layer.shadowOpacity = 0.0
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
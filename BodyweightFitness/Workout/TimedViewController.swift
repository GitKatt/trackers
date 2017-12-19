import UIKit
import AVFoundation

class TimedViewController: UIViewController, AVAudioPlayerDelegate {
    @IBOutlet var timerMinutesButton: UIButton!
    @IBOutlet var timerSecondsButton: UIButton!
    
    @IBOutlet var timerPlayButton: UIButton!
    
    @IBOutlet var previousButton: UIButton!
    @IBOutlet var nextButton: UIButton!
    
    var rootViewController: WorkoutViewController? = nil
    var current: Exercise = RoutineStream.sharedInstance.routine.getFirstExercise()
    
    var audioPlayer: AVAudioPlayer?
    var timePickerController: TimePickerController?
    var timer = Timer()
    var isPlaying = false
    
    var seconds = 60
    var defaultSeconds = 60
    var loggedSeconds = 0
    
    init() {
        super.init(nibName: "TimedView", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func changeExercise(_ currentExercise: Exercise) {
        self.current = currentExercise
        
        let savedSeconds = PersistenceManager.getTimer(currentExercise.exerciseId)
        
        self.loggedSeconds = 0
        self.defaultSeconds = savedSeconds
        
        self.restartTimer(savedSeconds)
        
        if let _ = self.current.previous {
            self.previousButton.isHidden = false
        } else {
            self.previousButton.isHidden = true
        }
        
        if let _ = self.current.next {
            self.nextButton.isHidden = false
        } else {
            self.nextButton.isHidden = true
        }
    }
    
    func updateLabel() {
        let (_, m, s) = secondsToHoursMinutesSeconds(seconds)
        
        timerMinutesButton.setTitle(printTimerValue(m), for: UIControlState())
        timerSecondsButton.setTitle(printTimerValue(s), for: UIControlState())
    }
    
    func printTimerValue(_ value: Int) -> String {
        if(value > 9) {
            return String(value)
        } else {
            return "0" + String(value)
        }
    }
  
    func secondsToHoursMinutesSeconds (_ seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    func stopTimer() {
        isPlaying = false
        
        timerPlayButton.setImage(
            UIImage(named: "play") as UIImage?,
            for: UIControlState())
        
        timer.invalidate()
        
        self.logSeconds()
    }
    
    func startTimer() {
        isPlaying = true
        
        timerPlayButton.setImage(
            UIImage(named: "pause") as UIImage?,
            for: UIControlState())
        
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(updateTimer),
            userInfo: nil,
            repeats: true
        )
    }
    
    func restartTimer(_ seconds: Int) {
        stopTimer()
        
        self.seconds = seconds
        self.logSeconds()
        
        updateLabel()
    }
    
    func updateTimer() {
        seconds -= 1
        loggedSeconds += 1
        
        if(seconds <= 0) {
            restartTimer(defaultSeconds)
            
            let defaults = Foundation.UserDefaults.standard
            if(defaults.object(forKey: "playAudioWhenTimerStops") != nil) {
                let playAudioWhenTimerStops = defaults.bool(forKey: "playAudioWhenTimerStops")
                if(playAudioWhenTimerStops) {
                    audioPlayerStart()
                }
            } else {
                audioPlayerStart()
            }
        }
        
        updateLabel()
    }
    func setTimeAction() {
        if let seconds = self.timePickerController?.getTotalSeconds() {
            self.defaultSeconds = seconds
            self.restartTimer(seconds)

            PersistenceManager.storeTimer(current.exerciseId, seconds: self.defaultSeconds)
        }
    }
    
    func logSeconds() {
        if let current = self.rootViewController?.current {
            if (loggedSeconds > 1 && current.isTimed()) {
                let realm = RepositoryStream.sharedInstance.getRealm()
                let repositoryRoutine = RepositoryStream.sharedInstance.getRepositoryRoutineForToday()
                
                if let repositoryExercise = repositoryRoutine.exercises.filter({
                    $0.exerciseId == current.exerciseId
                }).first {
                    let sets = repositoryExercise.sets
                    
                    try! realm.write {
                        if (sets.count == 1 && sets[0].seconds == 0) {
                            sets[0].seconds = loggedSeconds

                            self.showNotification(loggedSeconds)
                            self.showRestTimer()
                        } else if (sets.count >= 1 && sets.count < 9) {
                            let repositorySet = RepositorySet()
                            
                            repositorySet.exercise = repositoryExercise
                            repositorySet.isTimed = true
                            repositorySet.seconds = loggedSeconds
                            
                            sets.append(repositorySet)
                            
                            repositoryRoutine.lastUpdatedTime = Date()
                            
                            self.showNotification(loggedSeconds)
                            self.showRestTimer()
                        }
                        
                        realm.add(repositoryRoutine, update: true)
                    }

                    RoutineStream.sharedInstance.setRepository()
                }
            }
            
        }
        
        loggedSeconds = 0
    }
    
    func audioPlayerStart() {
        let alertSound = URL(fileURLWithPath: Bundle.main
            .path(forResource: "finished", ofType: "mp3")!)
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: alertSound, fileTypeHint: nil)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("AVAudioSession errors.")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, with:
                AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation)
        } catch {
            print("AVAudioSession errors.")
        }
    }
    
    func showRestTimer() {
        self.rootViewController?.restTimerShouldStart()
    }
    
    func showNotification(_ seconds: Int) {
        let notification = CWStatusBarNotification()
        
        notification.notificationLabelFont = UIFont.boldSystemFont(ofSize: 17)
        notification.notificationLabelBackgroundColor = UIColor.primary()
        notification.notificationLabelTextColor = UIColor.primaryDark()
        
        notification.notificationStyle = .navigationBarNotification
        notification.notificationAnimationInStyle = .top
        notification.notificationAnimationOutStyle = .top
        
        notification.displayNotificationWithMessage("Logged \(seconds) seconds", forDuration: 2.0)
    }
    
    @IBAction func increaseButton(_ sender: AnyObject) {
        seconds += 5
        updateLabel()
    }
    
    @IBAction func playButton(_ sender: AnyObject) {
        if(isPlaying) {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    @IBAction func restartButton(_ sender: AnyObject) {
        restartTimer(defaultSeconds)
    }
    
    @IBAction func timerButton(_ sender: AnyObject) {
        stopTimer()
        
        timePickerController = TimePickerController()
        timePickerController?.setDefaultTimer(self.seconds)
        
        let alertController = UIAlertController(title: "", message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let setTimeAlertAction = UIAlertAction(
            title: "Set Timer",
            style: UIAlertActionStyle.default) { action -> Void in self.setTimeAction() }
        
        alertController.setValue(timePickerController, forKey: "contentViewController");
        alertController.addAction(setTimeAlertAction)
        
        self.parent?.present(alertController, animated: true, completion: nil)
    }
    
    
    @IBAction func previousButtonClicked(_ sender: AnyObject) {
        self.rootViewController?.previousButtonClicked(sender)
    }
    
    @IBAction func nextButtonClicked(_ sender: AnyObject) {
        self.rootViewController?.nextButtonClicked(sender)
    }
}

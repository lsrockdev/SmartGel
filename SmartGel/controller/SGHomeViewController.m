//
//  SGHomeViewController.m
//  SmartGel
//
//  Created by jordi on 28/09/2017.
//  Copyright © 2017 AFCO. All rights reserved.
//

#import "SGHomeViewController.h"
#import "SGConstant.h"
#import "AppDelegate.h"
#import "SGFirebaseManager.h"
#import "SGUtil.h"
#import "SCLAlertView.h"
#import "SGTagViewController.h"
#import "UIImageView+WebCache.h"
#import "SGSharedManager.h"

@interface SGHomeViewController ()

@end

@implementation SGHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([FIRAuth auth].currentUser) {
        [self homeScreenInit];
    }else{
        [self anonymouslySignIn];
    }
    [self.manualModeView setAlpha:0.2];
    [self disableAllButtons];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if(isTakenPhoto){
        isTakenPhoto = false;
        [self initDataUiWithTakenImage:^(NSString *result) {
            [hud hideAnimated:false];
        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)homeScreenInit{
    [self initData];
    [self initSelectedTag:[SGSharedManager.sharedManager getTag]];
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [self initDeviceRotateNotification];
}

-(void)initDeviceRotateNotification{
    UIDevice *device = [UIDevice currentDevice];
    [device beginGeneratingDeviceOrientationNotifications];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(orientationChanged:)  name:UIDeviceOrientationDidChangeNotification
             object:device];
}

- (void)orientationChanged:(NSNotification *)note
{
//    if(self.estimateImage!=nil){
//        if(isShowDirtyArea){
//           [self hideDirtyArea];
//        }
//        [self drawGridView];
//        [self initCleanareaViews: self.engine.areaCleanState];
//    }
}

- (void)initData{
    isSavedImage = false;
    isSelectedFromCamera = false;
    isTakenPhoto = false;
    isAddCleanArea = false;
    isShowDirtyArea = false;
    self.cleanEditView.delegate = self;
    
    self.engine = [[DirtyExtractor alloc] init];
    self.manualEngine = [[DirtyExtractor alloc] init];
    
    [self initLocationManager];
    [self.dateLabel setText:[[SGUtil sharedUtil] getCurrentTimeString]];
}

/************************************************************************************************************************************
 * init location manager
 * get current location
 *************************************************************************************************************************************/

-(void)initLocationManager{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    if ([[[UIDevice currentDevice] systemVersion] floatValue]>=8.0) {
        [self.locationManager requestWhenInUseAuthorization];
        [self.locationManager requestAlwaysAuthorization];
    }
    [self.locationManager startMonitoringSignificantLocationChanges];
    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
    [self.locationManager stopUpdatingLocation];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error)
     {
         if(placemarks && placemarks.count > 0)
         {
             CLPlacemark *placemark= [placemarks objectAtIndex:0];
             NSString *address = [NSString stringWithFormat:@"%@ %@,%@ %@", [placemark subThoroughfare],[placemark thoroughfare],[placemark locality], [placemark administrativeArea]];
             self.locationLabel.text = address;
         }
     }];
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
    [self showAlertdialog:@"Error" message:@"Failed to Get Your Location"];
}

/************************************************************************************************************************************
 * get current user from firebase
 *************************************************************************************************************************************/

-(void)getCurrentUser{
    if([SGFirebaseManager sharedManager].currentUser == nil){
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        __weak typeof(self) wself = self;
        [[SGFirebaseManager sharedManager] getCurrentUserwithUserID:[FIRAuth auth].currentUser.uid
                                                  completionHandler:^(NSError *error, SGUser *sgUser) {
                                                      __strong typeof(wself) sself = wself;
                                                      if(sself){
                                                          [hud hideAnimated:false];
                                                          if (error!= nil){
                                                              [sself showAlertdialog:@"Error" message:error.localizedDescription];
                                                          }else{
                                                              [self homeScreenInit];
                                                          }
                                                      }
                                                  }];
    }else{
        [self homeScreenInit];
   }
}

- (void)anonymouslySignIn{
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [[FIRAuth auth] signInAnonymouslyWithCompletion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
        [self homeScreenInit];
        if(error != nil){
            [self showAlertdialog:nil message:error.localizedDescription];
        }
        [hud hideAnimated:false];
    }];
}

/************************************************************************************************************************************
 * Set labels from estimage data
 *************************************************************************************************************************************/

-(void)setLabelsWithEstimateData:(EstimateImageModel *)estimateImage{
    [self.valueLabel setText:[NSString stringWithFormat:@"%.1f%@", estimateImage.cleanValue,@"%"]];
    [self.dirtyvalueLabel setText:[NSString stringWithFormat:@"%.1f", CLEAN_MAX_VALUE - estimateImage.cleanValue]];
}

/************************************************************************************************************************************
 * show/hide clean area
 *************************************************************************************************************************************/

-(IBAction)autoDectectClicked{
    if(self.estimateImage.image == nil){
        [self showAlertdialog:nil message:@"Please take or choose a photo."];
        return;
    }
    [self.manualModeView setAlpha:0.2];
    [self disableAllButtons];
    [self.cleanEditView onSetAutoDetectMode];
    [self setLabelsWithEstimateData:self.estimateImage];
}

-(IBAction)manualModeClicked{
    if(self.estimateImage.image == nil){
        [self showAlertdialog:nil message:@"Please take or choose a photo."];
        return;
    }
    [self.manualModeView setAlpha:1.0];
    [self enableAllButtons];
    [self deselectAllButton];
    [self nonGelButtonClicked];
    [self.cleanEditView onSetManualMode];
    [self setLabelsWithEstimateData:self.manualEstimateImage];
}


/************************************************************************************************************************************
 * save photo
 *************************************************************************************************************************************/


-(IBAction)savePhoto{
    if(self.estimateImage.image == nil){
        [self showAlertdialog:nil message:@"Please take a photo."];
    }else{
        if(isSavedImage)
            [self showAlertdialog:nil message:@"You have already saved this Image."];
        else{
            [self showSaveAlertView:false];
        }
    }
}

- (void)saveResultImage{
    
    NSString *userID = [FIRAuth auth].currentUser.uid;
    if(userID == nil){
        [self showNoConnectionAlertdialogForSaving];
        return;
    }
    
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    if(self.cleanEditView.isAutoDetect){
        [[SGFirebaseManager sharedManager] saveResultImage:self.estimateImage
                                                selectedTag:self.selectedTag
                                        engineColorOffset :self.engine.m_colorOffset
                                         completionHandler:^(NSError *error) {
                                             [hud hideAnimated:false];
                                             if(error == nil){
                                                 isSavedImage = true;
                                                 [self showAlertdialog:@"Image Uploading Success!" message:error.localizedDescription];
                                             }else{
                                                 [self showAlertdialog:@"Image Uploading Failed!" message:error.localizedDescription];
                                             }
                                         }];
    }else{
        [[SGFirebaseManager sharedManager] saveResultImage:self.manualEstimateImage
                                               selectedTag:self.selectedTag
                                        engineColorOffset :self.engine.m_colorOffset
                                         completionHandler:^(NSError *error) {
                                             [hud hideAnimated:false];
                                             if(error == nil){
                                                 isSavedImage = true;
                                                 [self showAlertdialog:@"Image Uploading Success!" message:error.localizedDescription];
                                             }else{
                                                 [self showAlertdialog:@"Image Uploading Failed!" message:error.localizedDescription];
                                             }
                                         }];

    }
}

/************************************************************************************************************************************
 * launch photo picker controller
 * choose image from camera or gallery
 *************************************************************************************************************************************/

-(IBAction)launchPhotoPickerController{
    if(self.estimateImage.image == nil){
        [self showPhotoChooseActionSheet];
    }else{
        if(isSavedImage){
            [self showPhotoChooseActionSheet];
        }else{
            [self showSaveAlertView:true];
        }
    }
}

-(void)showPhotoChooseActionSheet{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet]; // 1
    UIAlertAction *firstAction = [UIAlertAction actionWithTitle:@"Camera"
                                                          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                              [self launchCameraScreen:true];
                                                          }];
    UIAlertAction *secondAction = [UIAlertAction actionWithTitle:@"Gallery"
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                               [self launchCameraScreen:false];
                                                           }];
    UIAlertAction *thirdAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
                                                           }];
    [alert addAction:firstAction];
    [alert addAction:secondAction];
    [alert addAction:thirdAction];
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        UIPopoverPresentationController *popPresenter = [alert
                                                         popoverPresentationController];
        popPresenter.sourceView = self.view;
        popPresenter.sourceRect = CGRectMake(self.view.frame.size.width-60, self.view.frame.size.height/2, 30, 0);
        [self presentViewController:alert animated:YES completion:nil];
    }else{
        [self presentViewController:alert animated:YES completion:nil];
    }
}

-(void)launchCameraScreen:(BOOL)isCamera{
    isSelectedFromCamera = isCamera;
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    if(isCamera){
        imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    }else{
        imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    [self presentViewController:imagePickerController animated:NO completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo{
    self.originalImage = image;
    self.estimateImage = [[EstimateImageModel alloc] initWithImage:image];
    self.manualEstimateImage = [[EstimateImageModel alloc] initWithImage:image];
    
    if(isSelectedFromCamera){
        UIImageWriteToSavedPhotosAlbum(image,nil,nil,nil);
    }
    isTakenPhoto = true;
    [self.dateLabel setText:[[SGUtil sharedUtil] getCurrentTimeString]];
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

/************************************************************************************************************************************
 * init data and UI from choose image
 *************************************************************************************************************************************/

-(void)initDataUiWithTakenImage:(void (^)(NSString *result))completionHandler{
    isSavedImage = false;
    [self initAutoDetectData];
    self.manualEngine = [[DirtyExtractor alloc] initWithImage:self.estimateImage.image];
    [self.manualEstimateImage setImageDataModel:self.manualEngine.cleanValue withDate:self.dateLabel.text withTag:self.tagLabel.text withLocation:self.locationLabel.text  withCleanArray:self.manualEngine.areaCleanState];
    [self.cleanEditView setImage:self.estimateImage.image withCleanArray:self.engine.areaCleanState];
    [self autoDectectClicked];
    completionHandler(@"completion");
}

-(void)initAutoDetectData{
    self.engine = [[DirtyExtractor alloc] initWithImage:self.estimateImage.image];
    [self.estimateImage setImageDataModel:self.engine.cleanValue withDate:self.dateLabel.text withTag:self.tagLabel.text withLocation:self.locationLabel.text  withCleanArray:self.engine.areaCleanState];
}

/************************************************************************************************************************************
 * touch action
 *************************************************************************************************************************************/

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch1 = [touches anyObject];
    CGPoint location = [touch1 locationInView:self.cleanEditView];
    if(CGRectContainsPoint(self.tagImageView.frame, location)){
        [self imgToFullScreen];
        return ;
    }
}



/************************************************************************************************************************************
 * Manual Mode Functions
 *************************************************************************************************************************************/

-(IBAction)nonGelButtonClicked{
    [self deselectAllButton];
    [self.cleanEditView addPanGesture];
    self.nonGelButton.backgroundColor = SGColorDarkYellow;
    self.addingType = NonGel;
}

-(IBAction)cleanButtonClicked{
    [self deselectAllButton];
    [self.cleanEditView addPanGesture];
    self.cleanButton.backgroundColor = SGColorDarkPink;
    self.addingType = Clean;
}

-(IBAction)dirtyButtonClicked{
    [self deselectAllButton];
    [self.cleanEditView addPanGesture];
    self.dirtyButton.backgroundColor = SGColorDarkGreen;
    self.addingType = Dirty;
}

-(IBAction)zoomButtonClicked{
    [self deselectAllButton];
    [self.cleanEditView removePanGesture];
    self.zoomButton.backgroundColor = SGColorDarkGreen;
}

-(IBAction)resetButtonClicked{
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.estimateImage = [[EstimateImageModel alloc] initWithImage:self.originalImage];
        self.manualEstimateImage = [[EstimateImageModel alloc] initWithImage:self.originalImage];
        [self initDataUiWithTakenImage:^(NSString *result) {
            [self manualModeClicked];
            [hud hideAnimated:false];
        }];
    });
}

-(void)deselectAllButton{
    self.nonGelButton.backgroundColor = SGColorButtonGray;
    self.cleanButton.backgroundColor = SGColorButtonGray;
    self.dirtyButton.backgroundColor = SGColorButtonGray;
    self.zoomButton.backgroundColor = SGColorButtonGray;
}

- (void)onTappedGridView:(int)touchLocation{
    
    if(self.addingType == NonGel){
        [self addManualNonGelArea:touchLocation];
    }else if(self.addingType == Clean){
        [self addManualCleanArea:touchLocation];
    }else if(self.addingType == Dirty){
        [self addManualDirtyArea:touchLocation];
    }
//    }else if(self.addingType == Erase){
//        [self eraseManualArea:touchLocation];
//    }
}

/************************************************************************************************************************************
 * add non-gel area
 *************************************************************************************************************************************/

-(void)addManualNonGelArea:(int)touchPosition{
    [self.manualEstimateImage updateNonGelAreaString:touchPosition];
    [self.manualEngine setNonGelAreaState:[self.manualEstimateImage getNonGelAreaArray]];
    [self.manualEstimateImage setCleanAreaWithArray:self.manualEngine.areaCleanState];
    [self.cleanEditView removeMaunalArea:touchPosition];
    
    [self setLabelsWithEstimateData:self.manualEstimateImage];
    self.manualEstimateImage.cleanValue = self.manualEngine.cleanValue;
}

/************************************************************************************************************************************
 * add manual clean area
 *************************************************************************************************************************************/

-(void)addManualCleanArea:(int)touchPosition{
    [self.manualEngine addCleanArea:touchPosition];
    [self.manualEstimateImage addNonGelAreaString:touchPosition withState:false];
    [self.manualEstimateImage updateManualCleanAreaString:touchPosition];
    [self.manualEstimateImage setCleanAreaWithArray:self.manualEngine.areaCleanState];
    [self.cleanEditView addManualCleanArea:touchPosition];
    
    [self setLabelsWithEstimateData:self.manualEstimateImage];
    self.manualEstimateImage.cleanValue = self.manualEngine.cleanValue;
}

-(void)addManualDirtyArea:(int)touchPosition{
    [self.manualEngine addDirtyArea:touchPosition];
    [self.manualEstimateImage addNonGelAreaString:touchPosition withState:false];
    [self.manualEstimateImage updateManualCleanAreaString:touchPosition];
    [self.manualEstimateImage setCleanAreaWithArray:self.manualEngine.areaCleanState];
    [self.cleanEditView addManualDirtyArea:touchPosition];
    
    [self setLabelsWithEstimateData:self.manualEstimateImage];
    self.manualEstimateImage.cleanValue = self.manualEngine.cleanValue;
}

-(void)eraseManualArea:(int)touchPosition{
    [self.cleanEditView removeMaunalArea:touchPosition];
}

-(void)removeMaunalCleanArea:(int)touchPosition{
    [self.engine removeManualCleanArea:touchPosition];
    [self.estimateImage updateManualCleanAreaString:touchPosition];
    [self.estimateImage setCleanAreaWithArray:self.engine.areaCleanState];
//    [self.cleanEditView removeMaunalCleanArea:touchPosition];
    
    [self setLabelsWithEstimateData:self.manualEstimateImage];
    self.manualEstimateImage.cleanValue = self.manualEngine.cleanValue;
}

/************************************************************************************************************************************
 * select tag
 * upload image
 *************************************************************************************************************************************/

-(IBAction)btnTagIndicatorTapped:(id)sender{
    SGTagViewController *tagVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SGTagViewController"];
    tagVC.delegate = self;
    [self.navigationController pushViewController:tagVC animated:YES];
}

- (void)showSaveAlertView:(bool)isFromPickerPhoto{
    
    [self getEditedShareImage];
    
    SCLAlertView *alert = [[SCLAlertView alloc] init];
    alert.customViewColor = SGColorBlack;
    alert.iconTintColor = [UIColor whiteColor];
    alert.tintTopCircle = NO;
    alert.backgroundViewColor = SGColorDarkGray;
    alert.view.backgroundColor = SGColorDarkGray;
    alert.backgroundType = SCLAlertViewBackgroundTransparent;

    alert.labelTitle.textColor = [UIColor whiteColor];

    UITextField *tagTextField = [alert addTextField:self.estimateImage.tag];
    tagTextField.placeholder = @"Type TAG in here!";
    [tagTextField setEnabled:true];
    [tagTextField setBackgroundColor:[UIColor clearColor]];
    [tagTextField setTextColor:[UIColor whiteColor]];

    [alert addButton:@"Done" actionBlock:^(void) {
        self.estimateImage.location = self.locationLabel.text;
        self.estimateImage.tag = tagTextField.text;
        [self shareContent];
//        [self saveResultImage];
    }];

    [alert addButton:@"Cancel" actionBlock:^(void) {
        if(isFromPickerPhoto){
            [self showPhotoChooseActionSheet];
        }
    }];

    [alert.viewText setTextColor:[UIColor whiteColor]];
    [alert showEdit:self title:@"Save Image?" subTitle:@"Do you want to save and export the result?" closeButtonTitle:nil duration:0.0f];
}

- (void)didSelectTag:(SGTag *)tag{
    [self initSelectedTag:tag];
    [SGSharedManager.sharedManager saveTag:tag];
}

-(void)initSelectedTag:(SGTag *)tag{
    self.selectedTag = tag;
    if(self.selectedTag.tagName){
        self.tagLabel.text = tag.tagName;
    }else{
        self.tagLabel.text = @"No Tag";
    }
    [self.tagImageView sd_setImageWithURL:[NSURL URLWithString:tag.tagImageUrl]
                         placeholderImage:[UIImage imageNamed:@""]
                                  options:SDWebImageProgressiveDownload];

}

-(void)imgToFullScreen{
    if (!isFullScreen) {
        [UIView animateWithDuration:0.5 delay:0 options:0 animations:^{
            //save previous frame
            prevFrame = self.tagImageView.frame;
            [self.tagImageView setFrame:[[UIScreen mainScreen] bounds]];
        }completion:^(BOOL finished){
            isFullScreen = true;
        }];
        return;
    } else {
        [UIView animateWithDuration:0.5 delay:0 options:0 animations:^{
            [self.tagImageView setFrame:prevFrame];
        }completion:^(BOOL finished){
            isFullScreen = false;
        }];
        return;
    }
}

//Edit Buttons operation

-(void)disableAllButtons{
    self.nonGelButton.enabled = false;
    self.cleanButton.enabled = false;
    self.dirtyButton.enabled = false;
    self.zoomButton.enabled = false;
    self.resetButton.enabled = false;
    self.cropButton.enabled = false;
    
    self.nonGelLargeButton.enabled = false;
    self.cleanLargeButton.enabled = false;
    self.dirtyLargeButton.enabled = false;
    self.zoomLargeButton.enabled = false;
    self.resetLargeButton.enabled = false;
    self.cropLargeButton.enabled = false;
}

-(void)enableAllButtons{
    self.nonGelButton.enabled = true;
    self.cleanButton.enabled = true;
    self.dirtyButton.enabled = true;
    self.zoomButton.enabled = true;
    self.resetButton.enabled = true;
    self.cropButton.enabled = true;
    
    self.nonGelLargeButton.enabled = true;
    self.cleanLargeButton.enabled = true;
    self.dirtyLargeButton.enabled = true;
    self.zoomLargeButton.enabled = true;
    self.resetLargeButton.enabled = true;
    self.cropLargeButton.enabled = true;
}

-(IBAction)cropButtonClicked{
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *image = [self.cleanEditView croppIngimageByImageName];
        self.estimateImage = [[EstimateImageModel alloc] initWithImage:image];
        self.manualEstimateImage = [[EstimateImageModel alloc] initWithImage:image];
        [self initDataUiWithTakenImage:^(NSString *result) {
            [hud hideAnimated:false];
            [self manualModeClicked];
            [self nonGelButtonClicked];
        }];
    });
}

-(void)shareContent{
    NSString * message = [NSString stringWithFormat:@"Value : %.2f\n Tag: %@\n Location: %@\n",self.engine.cleanValue,self.estimateImage.tag,self.estimateImage.location];
    NSArray * shareItems = @[message, self.originalImage, self.editedShareImage];
    UIActivityViewController * avc = [[UIActivityViewController alloc] initWithActivityItems:shareItems applicationActivities:nil];
    [self presentViewController:avc animated:YES completion:nil];
}

-(void)getEditedShareImage{
    if(self.cleanEditView.isAutoDetect){
        self.editedShareImage =[[SGImageUtil sharedImageUtil] getImageFromUIView:self.cleanEditView.imgview];
    }else{
        self.editedShareImage =[[SGImageUtil sharedImageUtil] getImageFromUIView:self.cleanEditView.manualImgview];
    }
}


@end

//
//  SGHomeViewController.m
//  SmartGel
//
//  Created by jordi on 28/09/2017.
//  Copyright © 2017 AFCO. All rights reserved.
//

#import "SGHomeViewController.h"
#import "SGHistoryViewController.h"
#import "SGConstant.h"
#import "AppDelegate.h"
#import "SGPictureEditViewController.h"

@interface SGHomeViewController ()

@end

@implementation SGHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initData];
    [self.dateLabel setText:[self getCurrentTimeString]];
//    [self loginFireBase];
    self.cleanareaViews = [NSMutableArray array];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if(isTakenPhoto){
        [self initDataUiWithImage];
        isTakenPhoto = false;
        [hud hideAnimated:false];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)initData{
    isSavedImage = false;
    isTakenPhoto = false;
    self.engine = [[DirtyExtractor alloc] init];
    self.estimateImage = [[EstimateImageModel alloc] init];
    [self initLocationManager];
    self.appDelegate.ref = [[FIRDatabase database] reference];
}

-(void)initDataUiWithImage{
    [self.takenImageView setImage:self.takenImage];
    [self.cleanareaViews removeAllObjects];
    isSavedImage = false;
    self.engine = [[DirtyExtractor alloc] initWithImage:self.takenImage];
    if(!self.notificationLabel.isHidden)
        [self.notificationLabel setHidden:YES];
    [self.dateLabel setText:[self getCurrentTimeString]];
    [self.valueLabel setText:[NSString stringWithFormat:@"%.2f", self.engine.cleanValue]];
    
    [self.estimateImage setImageDataModel:self.takenImage withEstimatedValue:self.engine.cleanValue withDate:self.dateLabel.text withLocation:self.locationLabel.text withCleanArray:self.engine.areaCleanState withNonGelArray:[self nonGelAreaArrayInit]];

    [self drawGridView];
    [self initCleanareaViews: self.engine.areaCleanState];
}

- (NSMutableArray *)nonGelAreaArrayInit{
    NSMutableArray *gelAreaArray = [[NSMutableArray alloc] init];
    for(int i=0;i<SGGridCount*SGGridCount;i++){
        [gelAreaArray addObject:@(false)];
    }
    return gelAreaArray;
}

-(void)drawGridView{
    [self.gridContentView.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    CGRect rect = [self calculateClientRectOfImageInUIImageView];
    self.gridView = [[SGGridView alloc] initWithFrame:rect];
    [self.gridView addGridViews:SGGridCount withColCount:SGGridCount];
    [self.gridContentView addSubview:self.gridView];
}

-(CGRect)calculateClientRectOfImageInUIImageView
{
    CGSize imgViewSize=self.takenImageView.frame.size;                  // Size of UIImageView
    CGSize imgSize=self.takenImage.size;                      // Size of the image, currently displayed
    CGFloat scaleW = imgViewSize.width / imgSize.width;
    CGFloat scaleH = imgViewSize.height / imgSize.height;
    CGFloat aspect=fmin(scaleW, scaleH);
    CGRect imageRect={ {0,0} , { imgSize.width*=aspect, imgSize.height*=aspect } };
    imageRect.origin.x=(imgViewSize.width-imageRect.size.width)/2;
    imageRect.origin.y=(imgViewSize.height-imageRect.size.height)/2;
    imageRect.origin.x+=self.takenImageView.frame.origin.x;
    imageRect.origin.y+=self.takenImageView.frame.origin.y;
    return imageRect;
}

-(void)loginFireBase{
    if(self.appDelegate.isAreadyLoggedIn){
        if(([FIRAuth auth].currentUser.email != nil) || (![[FIRAuth auth].currentUser.email isEqualToString:@""])){
            [self getUserData];
        }
    }
}

- (void)getUserData{
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.appDelegate.ref = [[FIRDatabase database] reference];
    self.appDelegate.storageRef = [[FIRStorage storage] reference];
    [[[self.appDelegate.ref child:@"users"] child:[FIRAuth auth].currentUser.uid] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        self.appDelegate.user = [[SGUser alloc] initWithSnapshot:snapshot];
        [hud hideAnimated:false];
    } withCancelBlock:^(NSError * _Nonnull error) {
        [self showAlertdialog:nil message:error.localizedDescription];
        [hud hideAnimated:false];
    }];
}

- (void)saveResultImage{
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.label.text = @"Uploading image...";
    FIRStorageReference *riversRef = [self.appDelegate.storageRef child:[NSString stringWithFormat:@"%@/%@.png",self.appDelegate.user.userID,self.estimateImage.date]];
    NSData *imageData = UIImageJPEGRepresentation(self.estimateImage.image,0.7);
    [riversRef putData:imageData
              metadata:nil
            completion:^(FIRStorageMetadata *metadata,NSError *error) {
                [hud hideAnimated:false];
                if (error != nil) {
                    [self showAlertdialog:@"Image Uploading Failed!" message:error.localizedDescription];
                } else {
                    isSavedImage = true;
                    [self showAlertdialog:@"Image Uploading Success!" message:error.localizedDescription];
                    NSDictionary *post = @{
                                           @"value": [NSString stringWithFormat:@"%.1f",self.estimateImage.cleanValue],
                                           @"image": metadata.downloadURL.absoluteString,
                                           @"tag": self.estimateImage.tag,
                                           @"date": self.estimateImage.date,
                                           @"location": self.estimateImage.location,
                                           @"cleanarea": self.estimateImage.cleanArea,
                                           @"nonGelArea": self.estimateImage.nonGelArea,
                                           @"coloroffset": [NSString stringWithFormat:@"%d", self.engine.m_colorOffset]
                                           };
                    NSDictionary *childUpdates = @{[NSString stringWithFormat:@"%@/%@/%@/%@",@"users", self.appDelegate.user.userID, @"photos",self.estimateImage.date]: post};
                    [self.appDelegate.ref updateChildValues:childUpdates];
                }
            }];
}


-(IBAction)backButtonPressed{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)showCleanAndDirtyArea{
    isShowDirtyArea = true;
    [self.notificationLabel setHidden:YES];
    [self.showCleanAreaLabel setText:@"Hide clean area"];
    [self.showCleanAreaButton setBackgroundColor:SGColorDarkGreen];
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (int i = 0; i<self.cleanareaViews.count; i++) {
            UIView *view = [self.cleanareaViews objectAtIndex:i];
            if([[self.engine.areaCleanState objectAtIndex:i] intValue] != NO_GEL)
                [self.takenImageView addSubview:view];
        }
        [hud hideAnimated:false];
    });
}

-(void)hideDirtyArea{
    isShowDirtyArea = false;
    [self.notificationLabel setHidden:NO];
    [self.showCleanAreaLabel setText:@"Show clean area"];
    [self.showCleanAreaButton setBackgroundColor:SGColorDarkPink];
    for (int i = 0; i<self.cleanareaViews.count; i++) {
        UIView *view = [self.cleanareaViews objectAtIndex:i];
        [view removeFromSuperview];
    }
}

-(void)initCleanareaViews:(NSMutableArray*)dirtyState{
    CGRect rect = [self calculateClientRectOfImageInUIImageView];
    float areaWidth = rect.size.width/AREA_DIVIDE_NUMBER;
    float areaHeight = rect.size.height/AREA_DIVIDE_NUMBER;
    for(int i = 0; i<(AREA_DIVIDE_NUMBER*AREA_DIVIDE_NUMBER);i++){
        int y = i/AREA_DIVIDE_NUMBER;
        int x = (AREA_DIVIDE_NUMBER-1) - i%AREA_DIVIDE_NUMBER;
        UIView *paintView=[[UIView alloc]initWithFrame:CGRectMake(x*areaWidth+rect.origin.x, y*areaHeight+rect.origin.y, areaWidth, areaHeight)];
        if([[dirtyState objectAtIndex:i] intValue] == IS_CLEAN){
            [paintView setBackgroundColor:[UIColor redColor]];
            [paintView setAlpha:0.3];
        }else if([[dirtyState objectAtIndex:i] intValue] == IS_DIRTY){
            [paintView setBackgroundColor:[UIColor blueColor]];
            [paintView setAlpha:0.2];
        }
        [self.cleanareaViews addObject:paintView];
    }
}

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

-(IBAction)savePhoto{
    if(self.estimateImage.image == nil){
        [self showAlertdialog:nil message:@"Please take a photo."];
    }else{
        if(isSavedImage)
            [self showAlertdialog:nil message:@"You have already saved this Image."];
        else{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Uploading Image"
                                                                           message:@"Are you sure want to upload image?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self saveResultImage];
            }]];

            [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            }]];

            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

-(IBAction)showHideCleanArea{
    if(self.estimateImage.image == nil){
        [self showAlertdialog:nil message:@"Please take a photo."];
        return;
    }
    if(isShowDirtyArea)
        [self hideDirtyArea];
    else
        [self showCleanAndDirtyArea];
}

-(IBAction)launchPhotoPickerController{
//    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
//    imagePickerController.delegate = self;
//    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
//    [self presentViewController:imagePickerController animated:NO completion:nil];

    self.takenImage = [UIImage imageNamed:@"test.png"];
    [self initDataUiWithImage];

//    NSString* imageURL = [self getImageUrl:3];
//    [self.takenImageView sd_setImageWithURL:[NSURL URLWithString:imageURL]
//                                  completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
//                              if(error==nil){
//                                  [self initDataUiWithImage:image];
//                              }
//                          }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo{
    self.takenImage = image;
    isTakenPhoto = true;
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if(isShowDirtyArea){
        UITouch *touch1 = [touches anyObject];
        CGPoint location = [touch1 locationInView:self.view];
        if(!CGRectContainsPoint(self.gridView.frame, location))
            return ;
        if(self.takenImage==nil)
            return;
        CGPoint touchLocation = [touch1 locationInView:self.gridView];
        int touchPosition = [self.gridView getContainsFrame:self.takenImage withPoint:touchLocation withRowCount:SGGridCount withColCount:SGGridCount];
        if(touchPosition != -1){
            [self updateDataAndUIbyTouch:touchPosition];
        }
    }
}

-(void)updateDataAndUIbyTouch:(int)touchPosition{
    [self.estimateImage updateNonGelAreaString:touchPosition];
    [self.engine setNonGelAreaState:[self.estimateImage getNonGelAreaArray]];
    [self.estimateImage setCleanAreaWithArray:self.engine.areaCleanState];
    
    int pointX = touchPosition/SGGridCount;
    int pointY = touchPosition%SGGridCount;
    int rate = AREA_DIVIDE_NUMBER/SGGridCount;
    for(int i = 0; i<rate;i++){
        for(int j = 0; j< rate; j++){
            NSUInteger postion = AREA_DIVIDE_NUMBER*rate*pointX+(i*AREA_DIVIDE_NUMBER)+(rate*pointY+j);
            UIView *view = [self.cleanareaViews objectAtIndex:postion];
            if([[self.engine.areaCleanState objectAtIndex:postion] intValue] == NO_GEL){
                [view removeFromSuperview];
            }else{
                [self.takenImageView addSubview:view];
            }
        }
    }
    [self.valueLabel setText:[NSString stringWithFormat:@"%.2f", self.engine.cleanValue]];
    self.estimateImage.cleanValue = self.engine.cleanValue;
}

-(void)launchPictureEditViewController{
    SGPictureEditViewController *pictureViewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SGPictureEditViewController"];
    pictureViewController.takenImage = self.takenImage;
    [self.navigationController pushViewController:pictureViewController animated:YES];
}

/////////////////////////////// remove-harded code////////////////////////////////////////////////////////////////////////////////

- (NSString *) getImageUrl:(int)index{
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"smartgel-tests" ofType:@"json"];
    NSString *stringContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"\n Result = %@",stringContent);
    NSData *objectData = [stringContent dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    NSDictionary *imageArrayDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:&jsonError];
    NSArray* keys=[imageArrayDict allKeys];
    NSLog(@"\n jsonError = %@",jsonError.description);
    NSDictionary* imageDict = [imageArrayDict objectForKey:[keys objectAtIndex:index]];
    return  [imageDict objectForKey :@"image"];
}

- (NSMutableArray *) getDirtyState:(int)index{
    NSString* filePath = [[NSBundle mainBundle] pathForResource:@"smartgel-tests" ofType:@"json"];
    NSString *stringContent = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"\n Result = %@",stringContent);
    NSData *objectData = [stringContent dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    NSDictionary *imageArrayDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:&jsonError];
    NSArray* keys=[imageArrayDict allKeys];
    NSLog(@"\n jsonError = %@",jsonError.description);
    NSDictionary* imageDict = [imageArrayDict objectForKey:[keys objectAtIndex:index]];
    NSString *dirtyAreaString = [imageDict objectForKey :@"dirtyarea"];
    return  [self getDirtyAreaArray:dirtyAreaString];
}

- (NSMutableArray *)getDirtyAreaArray :(NSString *)diryAreaString{
    NSData* data = [diryAreaString dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *values = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return values;
}

@end

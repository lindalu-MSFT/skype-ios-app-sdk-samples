//
//  OnlineMeetingViewController.m
//  BankingApp
//
//  Created by Aasveen Kaur on 1/16/17.
//  Copyright © 2017 Jason Kim. All rights reserved.
//
#define TOKEN_AND_DISCOVERYURI_REQUEST_URL "https://metiobank.cloudapp.net/GetAnonTokenJob"

#define MEETING_URL_REQUEST_URL "https://imbridge.cloudapp.net/GetAdhocMeetingJob"


#import "OnlineMeetingViewController.h"
#import "ChatViewController.h"
#import "VideoViewController.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>



@interface OnlineMeetingViewController ()
@property (weak, nonatomic) IBOutlet UITextView *meetingURL;
@property (weak, nonatomic) IBOutlet UITextField *displayName;
@property (weak, nonatomic) IBOutlet UIButton *join;
@property (weak, nonatomic) IBOutlet UILabel *tokenAndDiscoveryURISuccessLabel;

typedef void (^completionBlock)( NSData *data ,NSError *error);
@end

@implementation OnlineMeetingViewController

SfBApplication *onlineMeetingsfb ;
SfBConversation *onlineMeetingConversation ;
NSString *token;
NSString *discoveryURI;

#pragma mark - Lifecycle and helper functions
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // Configure Shared application instance for Online meeting
    onlineMeetingsfb = SfBApplication.sharedApplication;
    onlineMeetingsfb.configurationManager.maxVideoChannels = 1;
    onlineMeetingsfb.configurationManager.requireWifiForAudio = false;
    onlineMeetingsfb.configurationManager.requireWifiForVideo = false;
    onlineMeetingsfb.alertDelegate = self;
    onlineMeetingsfb.devicesManager.selectedSpeaker.activeEndpoint = SfBSpeakerEndpointLoudspeaker;
    
    // For OnPrem topolgies enablePreview features should be enabled for Audio/Video.
    onlineMeetingsfb.configurationManager.enablePreviewFeatures = [Util getEnablePreviewSwitchState];
    
    // Setup UI
    self.join.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.displayName.delegate = self;
    }

- (void)viewDidAppear:(BOOL)animated{
     // First POST request to fetch meeting URL
    [self sendPostRequestForMeetingURL];
}

#pragma mark - Send POST requests for online meeting call flow functions
//  POST request to fetch ad hoc Meeting URL
-(void) sendPostRequestForMeetingURL{
// request to Trusted Application API Service Application endpoint
    
    NSMutableURLRequest *meetingUrlRequest = [[NSMutableURLRequest alloc]initWithURL:([[NSURL alloc]initWithString:@MEETING_URL_REQUEST_URL])];
    meetingUrlRequest.HTTPMethod = @"POST";
    meetingUrlRequest.HTTPBody = [@"Subject=adhocMeeting&Description=adhocMeeting&AccessLevel=" dataUsingEncoding:NSUTF8StringEncoding];
    [self SendHttpRequest:meetingUrlRequest withBlock:^(NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(error == nil){
                
                NSError *e = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
                
                if (!json) {
                    NSLog(@"Error parsing JSON: %@", e);
                } else {
                    self.meetingURL.text = json[@"JoinUrl"];
                     NSLog(@"Successful! meeting URL>>%@", json[@"JoinUrl"]);
                    //Send second POST request to get discovery URI and TOKEN based on response meeting URL
                    [self sendPostRequestForTokenAndDiscoveryURI];

                }
            }
            else{
                NSLog(@"ERROR! Getting meeting URL failed>%@",error);
                
                [Util showErrorAlert:error inView:self];
                [self.navigationController popViewControllerAnimated:YES];
            }
        });
    }];

}

//  POST request to get token and discovery URI based on response meeting URL
-(void) sendPostRequestForTokenAndDiscoveryURI  {
     // request to Trusted Application API Service Application endpoint
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]initWithURL:([[NSURL alloc]initWithString:@TOKEN_AND_DISCOVERYURI_REQUEST_URL])];
    request.HTTPMethod = @"POST";
    NSString * HTTPBodyString = [NSString stringWithFormat:@"ApplicationSessionId=AnonMeeting&AllowedOrigins=http%%3a%%2f%%2flocalhost%%2f&MeetingUrl=%@", self.meetingURL.text];
    request.HTTPBody = [HTTPBodyString dataUsingEncoding:NSUTF8StringEncoding];
    self.join.enabled = false;
    [self SendHttpRequest:request withBlock:^(NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(error == nil){
                
                NSError *e = nil;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
                
                if (!json) {
                    NSLog(@"Error parsing JSON: %@", e);
                } else {
                    
                    discoveryURI = json[@"DiscoverUri"];
                    self.tokenAndDiscoveryURISuccessLabel.textColor = [UIColor darkGrayColor];
                    self.tokenAndDiscoveryURISuccessLabel.text = @"Success! Please join online meeting";
                    token = json[@"Token"];
                    self.join.enabled = true;
                    self.join.alpha = 1;
                    NSLog(@"Successful! token and discovery URI:%@, %@",json[@"Token"],json[@"DiscoverUri"]);
                }
            }
            else{
                NSLog(@"ERROR! Getting token and discovery URI failed>%@",error);
               [Util showErrorAlert:error inView:self];
                 [self.navigationController popViewControllerAnimated:YES];
            }
        });
    }];

    
}

// Helper function to send request
-(void)SendHttpRequest: (NSURLRequest *)request withBlock: (completionBlock) completionHandler{
    NSURLSession *sessionObject = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [sessionObject dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSInteger statusCode = 0;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        statusCode = httpResponse.statusCode;
       NSLog(@"statusCode-> %ld", (long)statusCode);
        if(statusCode == 200){
            completionHandler(data,nil);
        }
        else{
            if(error == nil){
                NSError* myError = [[NSError alloc]initWithDomain:@"custom error" code:statusCode userInfo:nil ];
                
               
                completionHandler( nil, myError);
            }
            else {
                completionHandler( nil, error );
            }
        }
        
    }];
    [task resume];
}

#pragma mark - Join online meeting anonymous with discover URI and token function

-(bool) shouldJoinMeeting  {
    NSError *e = nil;
     SfBConversation *conversationInstance =   [ onlineMeetingsfb joinMeetingAnonymousWithDiscoverUrl:[[NSURL alloc] initWithString:discoveryURI] authToken:token displayName:self.displayName.text error:&e].conversation;
    if(conversationInstance){
    onlineMeetingConversation = conversationInstance;
    
        return true;
    }
    else{
        NSLog(@"ERROR! Joining online meeting>%@",e);
        
              [Util showErrorAlert:e inView:self];
        }
    return false;
}

- (void)didReceiveAlert:(SfBAlert *)alert{
    [Util showErrorAlert:alert.error inView:self];
}
#pragma mark -  User button actions
// press "Join online meeting" button to join text or video online meeting
- (IBAction)JoinOnlineMeetingPressed:(UIButton *)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Join online meeting" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Join online chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self joinOnlineChat];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Join online video chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self joinOnlineVideoChat];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popoverController =  alertController.popoverPresentationController;
    if(popoverController != nil){
        popoverController.sourceView = sender;
        popoverController.sourceRect = sender.bounds;
        
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

-(void)joinOnlineChat{
    if([self shouldJoinMeeting]){
        [self performSegueWithIdentifier:@"joinOnlineChat" sender:nil];
        
    }
}

-(void)joinOnlineVideoChat{
    if([self shouldJoinMeeting]){
        [self performSegueWithIdentifier:@"joinOnlineAudioVideoChat" sender:nil];
        
    }
}

 #pragma mark -Segue navigation functions
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([segue.identifier isEqualToString:@"joinOnlineChat"]){
        ChatViewController* destination = segue.destinationViewController;
        destination.conversation = onlineMeetingConversation;
        
    }
    else if([segue.identifier isEqualToString:@"joinOnlineAudioVideoChat"]){
        VideoViewController* destination = segue.destinationViewController;
        destination.deviceManagerInstance = onlineMeetingsfb.devicesManager;
        destination.conversationInstance = onlineMeetingConversation;
        destination.displayName = self.displayName.text;
        
        discoveryURI = nil;
        token = nil;
    }
     onlineMeetingConversation = nil;
}


#pragma mark -  Lifecycle and helper functions
// reset UI when leaving this screen

-(void)viewDidDisappear:(BOOL)animated{
    self.displayName.text = self.displayName.placeholder;
    self.meetingURL.textColor = [UIColor redColor ];
    self.meetingURL.text = @"Waiting for online meeting URL!";
    self.tokenAndDiscoveryURISuccessLabel.textColor = [UIColor redColor ];
    self.tokenAndDiscoveryURISuccessLabel.text = @"Waiting for token and discovery URI!";
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [self.view endEditing:true];
    return false;
}




@end
//
//  ViewController.m
//  ChatClient
//
//  Created by taowang on 15/7/10.
//  Copyright © 2015年 Plague. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSStreamDelegate,UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UIView *chatView;
@property (weak, nonatomic) IBOutlet UITableView *tView;
@property (weak, nonatomic) IBOutlet UITextField *inputMessageField;
@property (weak, nonatomic) IBOutlet UITextField *inputNameField;
@property (strong, nonatomic) IBOutlet UIView *joinView;
- (IBAction)joinChat:(id)sender;
- (IBAction)sendMessage:(id)sender;

@end

@implementation ViewController
{
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    NSMutableArray * messages;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initNetworkCommunication];
    
    messages = [[NSMutableArray alloc] init];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)initNetworkCommunication {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)@"localhost", 80, &readStream, &writeStream);
    inputStream = (__bridge NSInputStream *)readStream;
    outputStream = (__bridge NSOutputStream *)writeStream;
    //设置代理
    [inputStream setDelegate:self];
    [outputStream setDelegate:self];
    //将stream添加到RunLoop
    //因为需要保证stream可以持续准备接收data，如果不设置runloop，那么代理将会阻塞代码的执行，直到stream的读和写都进行完成
    //应用需要对stream的行为做出反应，但是用受其摆布，而Runloop周期性的允许其他代码的执行，但是可以确保在stream发生event的时候通知你
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [inputStream open];
    [outputStream open];
}
- (IBAction)joinChat:(id)sender {
    //iam是因为在server.py中定义的输入用户名的标识
    NSString *response  = [NSString stringWithFormat:@"iam:%@", _inputNameField.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    [self.view bringSubviewToFront:_chatView];
}

- (IBAction)sendMessage:(id)sender {
    //类似iam，是信息的标识
    NSString *response = [NSString stringWithFormat:@"msg:%@",_inputMessageField.text];
    NSData *data = [[NSData alloc]initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [outputStream write:[data bytes] maxLength:[data length]];
    _inputMessageField.text = @""; // clean the field
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"ChatCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    NSString *s = (NSString *) [messages objectAtIndex:indexPath.row];
    cell.textLabel.text = s;
    return cell;
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return messages.count;
}
//NSStreamDelegate
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    switch (streamEvent) {
            //stream open finished
        case NSStreamEventOpenCompleted:
            NSLog(@"Stream opened");
            break;
            //able to read bytes
        case NSStreamEventHasBytesAvailable:
            if(theStream == inputStream){
                uint8_t buffer[1024];
                int len;
                while ([inputStream hasBytesAvailable]) {
                    //获取长度
                    len = (int)[inputStream read:buffer maxLength:sizeof(buffer)];
                    if (len > 0) {
                        //转化成string
                        NSString *output = [[NSString alloc]initWithBytes:buffer length:len encoding:NSASCIIStringEncoding];;
                        if (nil != output) {
                            NSLog(@"server said: %@", output);
                            //将string添加到array
                            [self messageReceived:output];
                        }
                    }
                }
            }
            break;
         //error
        case NSStreamEventErrorOccurred:
            NSLog(@"Can not connect to the host!");
            [theStream close];//失去连接关闭stream，将stream从runloop中移除
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            break;
            
        case NSStreamEventEndEncountered:
            break;
            
        default:
            NSLog(@"Unknown event");
    }
}
- (void) messageReceived:(NSString *)message {
    
    [messages addObject:message];
    [self.tView reloadData];
    NSIndexPath *topIndexPath =
    [NSIndexPath indexPathForRow:messages.count-1
                       inSection:0];
    [self.tView scrollToRowAtIndexPath:topIndexPath
                      atScrollPosition:UITableViewScrollPositionMiddle
                              animated:YES];
}
@end

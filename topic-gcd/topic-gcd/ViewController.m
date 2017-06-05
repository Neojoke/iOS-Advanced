//
//  ViewController.m
//  topic-gcd
//
//  Created by Neo on 2017/4/10.
//  Copyright © 2017年 Neo. All rights reserved.
//

#import "ViewController.h"
#include <unistd.h>
#include <utmpx.h>
@interface ViewController ()
@property(nonatomic,copy)NSString * name;
@property(nonatomic,copy)NSString * name1;
@property(nonatomic,copy)NSString * name2;
@property(nonatomic)dispatch_queue_t t;
@end

@implementation ViewController
@synthesize name = _name;
@synthesize name1 = _name1;
@synthesize name2 = _name2;
- (void)viewDidLoad {
    [super viewDidLoad];
    //使用串行队列同步执行读写操作
    self.t =dispatch_queue_create("com.topic-gcd.com", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        self.name = @"111";
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        //        NSLog(@"%@",self.name);
    });
    NSDate * date = [NSDate date];
    //串行队列，读操作同步执行，写操作异步执行，写操作在开辟新的线程中执行，执行返回再通知读操作的线程执行
    self.name = @"222";
    NSLog(@"%@",self.name);
    NSLog(@"name----%f",[NSDate date].timeIntervalSinceNow - date.timeIntervalSinceNow);
    date = [NSDate date];
    self.name1 = @"111";
    NSLog(@"%@",self.name1);
    NSLog(@"name1----%f",[NSDate date].timeIntervalSinceNow - date.timeIntervalSinceNow);
    //使用并行队列，读操作异步执行，写操作同步执行
    self.t = dispatch_queue_create(DISPATCH_CURRENT_QUEUE_LABEL, NULL);
    self.name2 = @"33";
    NSLog(@"1.read name2---->%@",self.name2);
    NSLog(@"2.read name2---->%@",self.name2);
    NSLog(@"3.read name2---->%@",self.name2);
    self.name2 = @"333";
    NSLog(@"4.read name2---->%@",self.name2);
    NSLog(@"5.read name2---->%@",self.name2);
    NSLog(@"6.read name2---->%@",self.name2);
    //使用Dispatch Group，并发队列异步执行任务
    dispatch_group_t group = dispatch_group_create();
    //在主线程队列中执行
    dispatch_group_async(group, dispatch_get_main_queue(), ^{
        NSLog(@"任务1执行");
    });
    //在创建的一个并行队列中执行
    dispatch_group_async(group, self.t, ^{
        NSLog(@"任务2执行");
    });
    //在全局队列中执行
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"任务3执行");
    });
    //死锁
//    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
//    NSLog(@"任务4执行");
    //在主线程队列中监听所有任务执行完毕的回调
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"任务5执行");
    });
    //创建QOS服务等级的队列
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, QOS_MIN_RELATIVE_PRIORITY);
    dispatch_queue_t concurrent_queue = dispatch_queue_create("concurrent_queue.com", attr);
    dispatch_async(concurrent_queue, ^{
        NSLog(@"concurrent_queue task exc");
    });
    //设置目标队列
    dispatch_queue_t targetQueue = dispatch_queue_create("test.target.queue", DISPATCH_QUEUE_SERIAL);
    
    
    
    dispatch_queue_t queue1 = dispatch_queue_create("test.1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue2 = dispatch_queue_create("test.2", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue3 = dispatch_queue_create("test.3", DISPATCH_QUEUE_SERIAL);
    
    dispatch_set_target_queue(queue1, targetQueue);
    dispatch_set_target_queue(queue2, targetQueue);
    dispatch_set_target_queue(queue3, targetQueue);
    
    
    dispatch_async(queue1, ^{
        NSLog(@"1 in");
        [NSThread sleepForTimeInterval:3.f];
        NSLog(@"1 out");
    });
    
    dispatch_async(queue2, ^{
        NSLog(@"2 in");
        [NSThread sleepForTimeInterval:2.f];
        NSLog(@"2 out");
    });
    dispatch_async(queue3, ^{
        NSLog(@"3 in");
        [NSThread sleepForTimeInterval:1.f];
        NSLog(@"3 out");
    });
    //dispatch_apply使用
//    dispatch_apply(100000, dispatch_queue_create(DISPATCH_CURRENT_QUEUE_LABEL, NULL), ^(size_t i) {
//        NSLog(@"%ld",i);
//    });
//    NSLog(@"finish");
    //使用dispatch_group_enter与dispatch_group_leave合并异步任务组
    dispatch_group_t block_group = dispatch_group_create();
    dispatch_group_enter(block_group);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"异步任务1");
        dispatch_group_leave(block_group);
    });
    dispatch_group_enter(block_group);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"异步任务2");
        dispatch_group_leave(block_group);
    });
    dispatch_group_notify(block_group, dispatch_get_main_queue(), ^{
        NSLog(@"异步任务1和任务2全部完成");
    });
    //dispatch_block_wait使用
    dispatch_queue_t block_serialQueue = dispatch_queue_create("com.block_serialQueue.com", DISPATCH_QUEUE_SERIAL);
    dispatch_block_t block = dispatch_block_create(0, ^{
        [NSThread sleepForTimeInterval:5.f];
        NSLog(@"block_serialQueue block end");
    });
    dispatch_async(block_serialQueue, block);
    //设置DISPATCH_TIME_FOREVER会一直等到前面任务都完成
    dispatch_block_wait(block, DISPATCH_TIME_FOREVER);
    block = dispatch_block_create(0, ^{
        NSLog(@"second block_serialQueue block end");
    });
    dispatch_async(block_serialQueue, block);
    dispatch_block_notify(block, dispatch_get_main_queue(), ^{
        NSLog(@"block_serialQueue block finished");
    });
    //使用Dispatch Group与dispatch_block_cancel，取消异步任务
    NSMutableArray * request_blocks = [NSMutableArray array];
    dispatch_group_t request_blocks_group = dispatch_group_create();
    //开启五个异步网络请求任务
    for (int i = 0; i<5; i++) {
        dispatch_block_t request_block = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, ^{
            NSURLRequest * request = [[NSURLRequest alloc]init];
           [self postWithRequest:request completion:^(id responseObjecy, NSURLResponse *response, NSError *error) {
              //do somethings
               dispatch_group_leave(request_blocks_group);
           }];
        });
        dispatch_group_enter(request_blocks_group);
        [request_blocks addObject:request_block];
        dispatch_async(dispatch_get_main_queue(), request_block);
    }
    //取消这五个任务
    for (dispatch_block_t request_block in request_blocks) {
        dispatch_group_leave(request_blocks_group);
        dispatch_block_cancel(request_block);
    }
    dispatch_group_notify(request_blocks_group, dispatch_get_main_queue(), ^{
        NSLog(@"网络任务请求执行完毕或者全部取消");
    });
    //dispatch_io_t的使用
    NSString * plist_path = [[NSBundle mainBundle]pathForResource:@"Info" ofType:@".plist"];
    dispatch_fd_t fd = open(plist_path.UTF8String, O_RDONLY);
    dispatch_queue_t queue = dispatch_queue_create("test io", NULL);
    dispatch_io_t pipe_channel = dispatch_io_create(DISPATCH_IO_STREAM, fd, queue, ^(int error) {
        close(fd);
    });
    dispatch_io_set_low_water(pipe_channel, SIZE_MAX);
    dispatch_io_read(pipe_channel, 0, SIZE_MAX, queue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
        if (error==0) {
            
        }
        if (done) {

        }
        size_t len = dispatch_data_get_size(data);
        if (len>0) {
            
        }
    });
    // Do any additional setup after loading the view, typically from a nib.
}
- (void)postWithRequest:(NSURLRequest *)request completion:(void(^)(id responseObjecy, NSURLResponse * response, NSError *error))completion{
    
}
-(NSString *)name{
    __block NSString * localName ;
    dispatch_sync(_t, ^{
        for (int i = 0; i<10000; i++) {
            
        }
        localName = _name;
    });
    return localName;
}
-(void)setName:(NSString *)name{
    dispatch_sync(_t, ^{
        _name = name;
    });
}
- (NSString *)name1{
    __block NSString * localName1;
    dispatch_sync(_t, ^{
        for (int i = 0; i<10000; i++) {
            
        }
        localName1 = _name1;
    });
    return localName1;
}
-(void)setName1:(NSString *)name1{
    dispatch_async(_t, ^{
        _name1 = name1;
    });
}
- (void)setName2:(NSString *)name2{
    dispatch_barrier_async(self.t, ^{
        _name2 = name2;
    });
}
- (NSString *)name2{
    __block NSString * localName2;
    dispatch_sync(self.t, ^{
        localName2 = _name2;
    });
    return localName2;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

#pragma once
#import <Foundation/Foundation.h>
#include <cstdint>
#include <functional>
#include <memory>

#if defined(__aarch64__)
// source须为已校验Build的存活MessageData；原生复制保留内部string/shared_ptr，不能memcpy。
// 原生消息快照由菜单动作及异步任务共享，最后一个持有者释放时析构。
struct YMMessageSnapshot {
    // 270102 为 0x350；旧版复制/析构只访问自身的 0x340，使用最大存储兼容两版。
    alignas(16) uint8_t storage[0x350];
    explicit YMMessageSnapshot(uintptr_t source);
    ~YMMessageSnapshot();
    YMMessageSnapshot(const YMMessageSnapshot &) = delete;
    YMMessageSnapshot &operator=(const YMMessageSnapshot &) = delete;
};
static_assert(sizeof(YMMessageSnapshot) == 0x350);
#endif

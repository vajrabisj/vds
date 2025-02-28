import net.http
import json
import os
import time

// Message represents a single message in the conversation
pub struct Message {
pub mut:
    role    string
    content string
}

// ChatRequest represents the request structure for the API
pub struct ChatRequest {
pub mut:
    model      string
    messages   []Message
    max_tokens int
}

// ChatResponse represents the response structure from the API
pub struct ChatResponse {
pub mut:
    choices []struct {
        message Message
    }
    error struct {
        message string
    }
}

// 实现全局请求计数，用于监控API调用频率
/*struct APIStats {
mut:
    request_count int
    last_request_time i64
}*/

fn main() {
    println('欢迎使用DeepSeek R1 Distill Llama 70B交互程序！输入"退出"以结束对话。')
    
    base_url := 'https://agent-f21a76a2830b44f6220f-tfj36.ondigitalocean.app/api/v1/chat/completions'
    api_key := 'pq4GsilLVPCVVKY5sHciDElcvsLXiVSO'
    
    // 初始化对话历史
    mut messages := []Message{}
    
    // 初始化API统计
    /*mut stats := APIStats{
        request_count: 0
        last_request_time: time.now()
    }*/
    
    for {
        print('你: ')
        user_input := os.input('')
        
        // 检查用户退出命令
        if user_input.trim_space().to_lower() == '退出' {
            println('再见！')
            break
        }
        
        // 添加用户消息到历史
        messages << Message{
            role: 'user'
            content: user_input
        }
        
        // 尝试进行API调用，如果失败则最多重试3次
        mut success := false
        mut retry_count := 0
        mut ai_message := ''
        
        for retry_count < 3 && !success {
            if retry_count > 0 {
                println('尝试重新连接...（第${retry_count}次重试）')
                // 重试间增加延迟
                time.sleep(1000 * time.millisecond * retry_count)
            }
            
            // 调用API并处理结果
			println('calling api...')
			ai_message = call_api(base_url, api_key, messages) or {
			println('API调用失败: ${err}')
			retry_count++
			continue
		}
		success = true
		}
		
		if success {
		println('success: ${success}')
		println('retry count: ${retry_count}')
		}
        
        if !success {
            println('多次尝试后仍无法获取AI回复，请检查网络连接或API状态。')
            println('按回车键继续...')
            os.input('')
            continue
        }
        
        println('AI: ${ai_message}')
        
        // 将AI回复添加到历史
        messages << Message{
            role: 'assistant'
            content: ai_message
        }
        
        // 防止对话历史过长
        if messages.len > 10 {
            messages = messages[messages.len - 10..]
        }
    }
}

// 封装API调用逻辑为单独函数，便于错误处理和资源管理
fn call_api(base_url string, api_key string, messages []Message /*mut stats APIStats*/) !string {
    // 更新API统计
    /*now := time.now()
    time_since_last := now - stats.last_request_time
    stats.request_count++
    stats.last_request_time = now*/
    
    // 如果请求频率过高，增加延迟
    /*if time_since_last < 2 && stats.request_count > 1 {
        println('请求频率控制中...')
        time.sleep(2000 * time.millisecond)
    }*/
    
    // 准备请求数据
    request_data := ChatRequest{
        model: 'deepseek-r1-distill-llama-70b'
        messages: messages
        max_tokens: 1000
    }
    
    // 编码为JSON
    json_data := json.encode(request_data)
    
    println('正在发送请求到API...')
    
    // 创建HTTP配置
	println('doing fetchconfig...')
    mut config := http.FetchConfig{
        url: base_url
        method: .post
        data: json_data
        header: http.new_header(
            key: .content_type, 
            value: 'application/json'
        )
    }
    
    // 添加授权头
	println('adding auth header...')
    if api_key != '' {
        config.header.add_custom('Authorization', 'Bearer ${api_key}') or {
            return err
        }
    }
    
    // 发送请求 - 这里使用 30 秒作为默认超时，V 会处理
	println('fetching...')
    mut resp := http.fetch(config) or {
        return err
    }
    
    // 获取并处理响应体
	println('getting response body...')
    response_body := resp.body
    
    // 检查HTTP状态
	println('checking status...')
    if resp.status_code != 200 {
        return error('API返回错误状态码: ${resp.status_code}, 响应: ${response_body}')
    }
    
    // 解析响应
	println('decoding response...')
    response := json.decode(ChatResponse, response_body) or {
        return error('无法解析JSON响应: ${err}, 原始响应: ${response_body}')
    }
    
    // 验证响应
	println('validating response...')
    if response.choices.len == 0 {
        return error('API返回了空的选择列表')
    }
    
    // 返回AI消息内容
	println('returning response...')
    return response.choices[0].message.content
}

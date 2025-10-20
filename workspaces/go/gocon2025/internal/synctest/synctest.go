package synctest

import (
	"context"
	"time"
)

// TaskProcessor は非同期でタスクを処理するインターフェース
type TaskProcessor interface {
	// ProcessWithDelay 指定した遅延後にタスクを処理する
	ProcessWithDelay(ctx context.Context, delay time.Duration, message string) <-chan string
	// ProcessWithPolling 定期的にポーリングして結果を返す
	ProcessWithPolling(ctx context.Context, interval time.Duration, maxRetries int) <-chan bool
	// ProcessWithGoroutine ゴルーチンでタスクを実行し、完了を通知する
	ProcessWithGoroutine(ctx context.Context, tasks []string) <-chan string
}

// VideoProcessor は動画処理のインターフェース
type VideoProcessor interface {
	// GenerateFrames 動画のNフレーム目の画像を生成する
	GenerateFrames(ctx context.Context, totalFrames int) <-chan int
}

// taskProcessor はTaskProcessorの具象実装
type taskProcessor struct{}

// NewTaskProcessor TaskProcessorの新しいインスタンスを作成する
func NewTaskProcessor() TaskProcessor {
	return &taskProcessor{}
}

// ProcessWithDelay 指定した遅延後にタスクを処理する
func (p *taskProcessor) ProcessWithDelay(ctx context.Context, delay time.Duration, message string) <-chan string {
	result := make(chan string, 1)

	go func() {
		defer close(result)

		select {
		case <-time.After(delay):
			result <- "処理完了: " + message
		case <-ctx.Done():
			return
		}
	}()

	return result
}

// ProcessWithPolling 定期的にポーリングして結果を返す
func (p *taskProcessor) ProcessWithPolling(ctx context.Context, interval time.Duration, maxRetries int) <-chan bool {
	result := make(chan bool, 1)

	go func() {
		defer close(result)

		// ゼロ以下の間隔の場合は最小値に設定
		if interval <= 0 {
			interval = 1 * time.Nanosecond
		}

		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		retries := 0
		for {
			select {
			case <-ticker.C:
				retries++
				// 3回目で成功するシミュレーション
				if retries >= 3 {
					result <- true
					return
				}
				if retries >= maxRetries {
					result <- false
					return
				}
			case <-ctx.Done():
				return
			}
		}
	}()

	return result
}

// ProcessWithGoroutine ゴルーチンでタスクを実行し、完了を通知する
func (p *taskProcessor) ProcessWithGoroutine(ctx context.Context, tasks []string) <-chan string {
	result := make(chan string, len(tasks))

	for _, task := range tasks {
		go func(t string) {
			select {
			case <-time.After(100 * time.Millisecond): // 各タスクに100ms必要
				result <- "タスク完了: " + t
			case <-ctx.Done():
				return
			}
		}(task)
	}

	return result
}

// videoProcessor はVideoProcessorの具象実装
type videoProcessor struct{}

// NewVideoProcessor VideoProcessorの新しいインスタンスを作成する
func NewVideoProcessor() VideoProcessor {
	return &videoProcessor{}
}

// GenerateFrames 動画のNフレーム目の画像を生成する
func (p *videoProcessor) GenerateFrames(ctx context.Context, totalFrames int) <-chan int {
	result := make(chan int, totalFrames)

	go func() {
		defer close(result)

		for i := 1; i <= totalFrames; i++ {
			select {
			case <-time.After(50 * time.Millisecond): // 各フレーム生成に50ms必要
				result <- i
			case <-ctx.Done():
				return
			}
		}
	}()

	return result
}

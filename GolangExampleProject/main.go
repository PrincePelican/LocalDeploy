package main

import (
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func newRouter() *gin.Engine {
	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery())

	router.GET("/hello", func(c *gin.Context) {
		c.String(http.StatusOK, "Hello")
	})

	return router
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8040"
	}

	if err := newRouter().Run(":" + port); err != nil {
		panic(err)
	}
}

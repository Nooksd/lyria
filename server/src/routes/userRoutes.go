package routes

import (
	controller "server/src/controllers"
	middleware "server/src/middlewares"

	"github.com/gin-gonic/gin"
)

func UserRoutes(router *gin.Engine) {
	router.Use(middleware.Authenticate())
	router.POST("/users/create", controller.CreateUser())
	router.GET("/users", controller.SearchUsers())
	router.POST("/avatar/upload", controller.UploadAvatar())
	router.GET("/users/:userId", controller.GetOneUser())
	router.PUT("/users/update/:userId", controller.UpdateOneUser())

	router.GET("/user/playlists", controller.GetOwnPlaylists())
}

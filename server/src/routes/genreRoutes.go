package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func GenreRoutes(router *gin.RouterGroup) {
	router.GET("/genre/:genre", controller.SearchByGenre())
}

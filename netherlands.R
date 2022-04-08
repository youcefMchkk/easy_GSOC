library ("iotables")
library ("ioanalysis")
library("igraph")
library ("tibble")
library ("dplyr")

options(scipen = 999) #so number are represented in the normal mode

#the open input output model

#Input-output table of domestic output at basic prices
data ("netherlands_2006")

#building the InputOutput object
#---------------------------------------------------------------
#the rows labels
rowlabels <- netherlands_2006[1:13 , 1]

#the columns labels
collabels <- names (netherlands_2006)


#the domestic intermediate matrix
#A nxn matrix of intermediate transactions between sectors.
Z <- matrix(unlist(netherlands_2006[1:6 , 2:7]) , nrow = 6)

#Domestic investment (GFCF) matrix
#------------------------------------------
# A nxm matrix of final demand. Exports SHOULD NOT be included in this matrix.
f <- matrix(unlist(netherlands_2006[1:6, 9:12]), nrow = dim(Z)[1])

#A nxr matrix of exports.
E <- matrix(unlist(netherlands_2006[1:6, 13]), ncol = 1)
#---------------------------------------------


#A 1xn vector of total production for each sector
X <- matrix(unlist(netherlands_2006[1:6, 14]), ncol = 1)


# Imported intermediate products matrix
#------------------------------------------------------
#V	 Value added
V <- matrix (unlist(netherlands_2006[9:12 , 2:7]) , nrow = 4)

#M imports
M <- netherlands_2006[8 , 2:7]
#------------------------------------------------------

#Imported investment (GFCF) matrix
#fV	 The matrix of final demand's value added
fV <- matrix(unlist(netherlands_2006[8:10 , 9:12]) , nrow = 3)



#making the InputOutput object

#making the RS_label
#A nx2 "column" matrix of the regions in column 1 and sector in column 2.
region <- rep("netherlands",times=6) # the region vector
sectors <- rowlabels[ 1:6]
RS_label = cbind(region , sectors)

#making the f_label
#A 2xn "row" matrix of the region and accounts to help identify the elements of f.
account <- t(collabels[9:12])
f_label = rbind(region[1:4] , account)

#making the E_label
#A 2xn "row" matrix of the region and type of export to help identify the elements of E.
E_label = rbind ("netherlands" , "exports")


#making the V label
# Column matrix of labels for types of value added for V
V_label = rowlabels[9:12]

#making the M label
# Column matrix of labels for type of imports for M
M_label = "imports"

#making the fV label
# Column matrix to identify the row elements of fV
fV_label = rowlabels[8:10] 



#building the object

myioobj <- as.inputoutput(Z = Z, RS_label = RS_label,
                          f = f, f_label = f_label,
                          E = E, E_label = E_label,
                          X = X,
                          V = V, V_label = V_label,
                          M = M, M_label =M_label,
                          fV = fV, fV_label = fV_label
                          )


#--------------------------------------------------------------------


#doing some analysis with ioanalysis package

#we have in myioobj.B the coefficients of the domestic intermediate matrix
ceof <- myioobj[["B"]]


#backward linkages of a product suggest what other products have contributed to make or produce one particular product. 
#And forward linkage refers to what other products can be built, produced, or made using that particular product.
#here is the backward and foward linkage of the InputOutput object
linkages(myioobj)

#Visualize the ceof matrix
heatmap.io(ceof, myioobj$RS_label)

#removing variables we don't need
#remove (E , E_label , f , f_label , fV , fV_label , M , RS_label , V , X , Z , fV_label , M_label , V_label , region , sectors , account , ceof)


#--------------------------------------------------------------------
#doing network analysis and visualization with igraph

#modifying the netherlands table to a adjacency matrix

graph_io <- netherlands_2006

#naming the columns
rownames(graph_io) <- rowlabels
colnames(graph_io) <- collabels

#deleting rows and columns we don't need
graph_io <- subset(graph_io , select = - c(prod_na , TOTAL , total_use))
graph_io <- graph_io [- c(10 , 13 , 7) ,]

#modifying values (NA -> 0 , n -> abs(n)) so we don't get any errors
graph_io[9:10  , 7:11] <-0
graph_io[8 , 9] <- abs(graph_io [8 , 9]) #there is only one negative value, we'll change it just so we don't have any problems

#adding new columns and rows so it will be an adjacency matrix
#adding columns
empty_col <- data.frame (imports = rep(0 , times = 10), 
                         net_tax = rep(0 , times = 10) ,
                         compensation_employees = rep(0 , times = 10),
                         value_added_bp = rep(0 , times = 10))

graph_io <- cbind(graph_io , empty_col)
graph_io <- graph_io[, c(1:6 , 12:15 , 7:11)]

#adding rows
empty_row <- data.frame(rbind(final_consumption_private = rep(0 , times = 15) ,
                        final_consumption_households = rep(0 , times = 15) ,
                        final_consumption_government = rep(0 , times = 15) ,
                        gross_fixed_capital_formation = rep(0 , times = 15) ,
                        exports = rep(0 , times = 15)))

colnames(empty_row) <- colnames(graph_io)
graph_io <- rbind (graph_io , empty_row)

#transforming it into a matrix
graph_io <- matrix(unlist(graph_io) , nrow = 15 , ncol = 15 , dimnames = list(rownames(graph_io) , colnames(graph_io)))

#making the graph
iograph <- graph_from_adjacency_matrix(graph_io , mode = "directed" , weighted = TRUE)

#doing some centrality measures analysis

#degree centrality
cdegree <- degree(iograph , mode = "all")
V(iograph)$degree <- cdegree

#eigenvector centrality
ioeigen <- evcent(iograph , directed = TRUE)$vector
V(iograph)$Eigen <- ioeigen

#betweennes centrality
btw_iograph <- betweenness(iograph)
V(iograph)$betweennes <- btw_iograph

#Summation
summ <- as_long_data_frame(iograph)

knitr::kable(summ[1:10 , ])
#graph visualization

#making shortcuts labels for the graph
vlabel = c("agr" , "min" , "man" , "utl" , "cns" , "srv" , "imp" , "ntx" , "cme" , "vla" , "fcp" , "fch" , "fcg" , "gfc" , "exp")
plot (iograph ,
      vertex.size = cdegree*1.5 , 
      edge.arrow.size = 0.3 , 
      vertex.label = vlabel , 
      vertex.label.cex = 0.7 , 
      layout=layout_nicely(iograph)
      )


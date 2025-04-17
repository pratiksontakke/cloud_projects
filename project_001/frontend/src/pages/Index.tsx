
import React, { useState, useEffect } from "react";
import { useQueryClient, useQuery, useMutation } from "@tanstack/react-query";
import { toast } from "sonner";
require('dotenv').config();

import Header from "@/components/Header";
import Footer from "@/components/Footer";
import TutorialsList from "@/components/TutorialsList";
import TutorialForm from "@/components/TutorialForm";
import TutorialDetail from "@/components/TutorialDetail";

import { tutorialService, Tutorial } from "@/services/tutorialService";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";

import {
  Plus,
  Search,
  AlertTriangle,
  RefreshCw,
  BookOpen,
  Trash2,
  FileCheck,
  LayoutDashboard,
} from "lucide-react";

const Index = () => {
  const queryClient = useQueryClient();
  const [searchTitle, setSearchTitle] = useState("");
  const [activeTab, setActiveTab] = useState("all");
  const [selectedTutorial, setSelectedTutorial] = useState<Tutorial | null>(null);
  const [viewTutorial, setViewTutorial] = useState<Tutorial | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [showDeleteAllConfirm, setShowDeleteAllConfirm] = useState(false);
  const [isViewMode, setIsViewMode] = useState(false);

  // Fetch tutorials based on active tab
  const {
    data: tutorials = [],
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ["tutorials", activeTab, searchTitle],
    queryFn: async () => {
      if (activeTab === "published") {
        return tutorialService.findAllPublished();
      } else {
        return tutorialService.getAll(searchTitle);
      }
    },
  });

  // Create tutorial mutation
  const createMutation = useMutation({
    mutationFn: tutorialService.create,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tutorials"] });
      setShowForm(false);
      setSelectedTutorial(null);
    },
  });

  // Update tutorial mutation
  const updateMutation = useMutation({
    mutationFn: (tutorial: Tutorial) => 
      tutorialService.update(tutorial.id!, tutorial),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tutorials"] });
      setShowForm(false);
      setSelectedTutorial(null);
    },
  });

  // Delete tutorial mutation
  const deleteMutation = useMutation({
    mutationFn: (id: number) => tutorialService.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tutorials"] });
      setShowDeleteConfirm(false);
      setSelectedTutorial(null);
    },
  });

  // Delete all tutorials mutation
  const deleteAllMutation = useMutation({
    mutationFn: tutorialService.deleteAll,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tutorials"] });
      setShowDeleteAllConfirm(false);
    },
  });

  // Get single tutorial for view mode
  const {
    data: tutorialDetail,
    isLoading: isLoadingDetail,
  } = useQuery({
    queryKey: ["tutorial", viewTutorial?.id],
    queryFn: () => viewTutorial ? tutorialService.getById(viewTutorial.id!) : null,
    enabled: !!viewTutorial?.id && isViewMode,
  });

  // Handle form submission
  const handleSubmit = (tutorial: Tutorial) => {
    if (tutorial.id) {
      updateMutation.mutate(tutorial);
    } else {
      createMutation.mutate(tutorial);
    }
  };

  // Handle tutorial deletion
  const handleDeleteConfirm = () => {
    if (selectedTutorial?.id) {
      deleteMutation.mutate(selectedTutorial.id);
    }
  };

  // Handle all tutorials deletion
  const handleDeleteAllConfirm = () => {
    deleteAllMutation.mutate();
  };

  // Handle search
  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    refetch();
  };

  // Reset search
  const resetSearch = () => {
    setSearchTitle("");
    setActiveTab("all");
  };

  // View tutorial details
  const handleViewTutorial = (id: number) => {
    const tutorial = tutorials.find(t => t.id === id);
    if (tutorial) {
      setViewTutorial(tutorial);
      setIsViewMode(true);
    }
  };

  // Edit tutorial
  const handleEditTutorial = (tutorial: Tutorial) => {
    setSelectedTutorial(tutorial);
    setShowForm(true);
    setIsViewMode(false);
  };

  // Back from view mode
  const handleBackFromView = () => {
    setViewTutorial(null);
    setIsViewMode(false);
  };

  return (
    <div className="flex flex-col min-h-screen">
      <Header />
      
      <main className="flex-1 container mx-auto px-4 py-8">
        {isViewMode ? (
          <TutorialDetail 
            tutorial={tutorialDetail || viewTutorial} 
            onBack={handleBackFromView} 
          />
        ) : (
          <div className="space-y-6">
            {/* Control Panel */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <Card className="md:col-span-2">
                <CardHeader className="pb-3">
                  <CardTitle className="text-xl flex items-center gap-2">
                    <Search size={18} />
                    Search Tutorials
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <form onSubmit={handleSearch} className="flex items-center gap-2">
                    <Input
                      placeholder="Search by title..."
                      value={searchTitle}
                      onChange={(e) => setSearchTitle(e.target.value)}
                      className="flex-1"
                    />
                    <Button type="submit">Search</Button>
                    {searchTitle && (
                      <Button type="button" variant="ghost" onClick={resetSearch}>
                        Clear
                      </Button>
                    )}
                  </form>
                </CardContent>
              </Card>
              
              <Card>
                <CardHeader className="pb-3">
                  <CardTitle className="text-xl flex items-center gap-2">
                    <LayoutDashboard size={18} />
                    Actions
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="flex flex-col gap-2">
                    <Button 
                      onClick={() => {
                        setSelectedTutorial(null);
                        setShowForm(true);
                      }}
                      className="w-full justify-start gap-2 bg-scientific-purple hover:bg-scientific-purple/90"
                    >
                      <Plus size={16} />
                      Create New Tutorial
                    </Button>
                    
                    <Button 
                      variant="outline" 
                      onClick={() => refetch()}
                      className="w-full justify-start gap-2"
                    >
                      <RefreshCw size={16} />
                      Refresh List
                    </Button>
                    
                    <Button 
                      variant="destructive" 
                      onClick={() => setShowDeleteAllConfirm(true)}
                      disabled={!tutorials.length}
                      className="w-full justify-start gap-2"
                    >
                      <Trash2 size={16} />
                      Delete All Tutorials
                    </Button>
                  </div>
                </CardContent>
              </Card>
            </div>
            
            {/* Main Content */}
            <Tabs value={activeTab} onValueChange={setActiveTab}>
              <div className="flex justify-between items-center mb-4">
                <TabsList>
                  <TabsTrigger value="all" className="flex items-center gap-1">
                    <BookOpen size={16} />
                    All Tutorials
                  </TabsTrigger>
                  <TabsTrigger value="published" className="flex items-center gap-1">
                    <FileCheck size={16} />
                    Published Only
                  </TabsTrigger>
                </TabsList>
                
                <div className="text-sm text-muted-foreground">
                  {tutorials.length} {tutorials.length === 1 ? 'tutorial' : 'tutorials'} found
                </div>
              </div>
              
              <TabsContent value="all" className="space-y-4 mt-2">
                {isLoading ? (
                  <Card className="p-8 flex justify-center">
                    <div className="flex items-center gap-2">
                      <RefreshCw size={20} className="animate-spin" />
                      <span>Loading tutorials...</span>
                    </div>
                  </Card>
                ) : isError ? (
                  <Alert variant="destructive">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertTitle>Error</AlertTitle>
                    <AlertDescription>
                      Failed to load tutorials. Please check your API connection and try again.
                    </AlertDescription>
                  </Alert>
                ) : (
                  <TutorialsList
                    tutorials={tutorials}
                    onEdit={handleEditTutorial}
                    onDelete={(id) => {
                      const tutorial = tutorials.find(t => t.id === id);
                      if (tutorial) {
                        setSelectedTutorial(tutorial);
                        setShowDeleteConfirm(true);
                      }
                    }}
                    onView={handleViewTutorial}
                  />
                )}
              </TabsContent>
              
              <TabsContent value="published" className="space-y-4 mt-2">
                {isLoading ? (
                  <Card className="p-8 flex justify-center">
                    <div className="flex items-center gap-2">
                      <RefreshCw size={20} className="animate-spin" />
                      <span>Loading published tutorials...</span>
                    </div>
                  </Card>
                ) : isError ? (
                  <Alert variant="destructive">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertTitle>Error</AlertTitle>
                    <AlertDescription>
                      Failed to load published tutorials. Please check your API connection and try again.
                    </AlertDescription>
                  </Alert>
                ) : (
                  <TutorialsList
                    tutorials={tutorials}
                    onEdit={handleEditTutorial}
                    onDelete={(id) => {
                      const tutorial = tutorials.find(t => t.id === id);
                      if (tutorial) {
                        setSelectedTutorial(tutorial);
                        setShowDeleteConfirm(true);
                      }
                    }}
                    onView={handleViewTutorial}
                  />
                )}
              </TabsContent>
            </Tabs>
            
            {/* Tutorial Form Dialog */}
            {showForm && (
              <Dialog open={showForm} onOpenChange={setShowForm}>
                <DialogContent className="sm:max-w-[550px]">
                  <DialogHeader>
                    <DialogTitle>
                      {selectedTutorial?.id ? 'Edit Tutorial' : 'Create New Tutorial'}
                    </DialogTitle>
                    <DialogDescription>
                      {selectedTutorial?.id 
                        ? 'Update the details of your tutorial below.'
                        : 'Fill out the form below to create a new tutorial.'}
                    </DialogDescription>
                  </DialogHeader>
                  <TutorialForm
                    tutorial={selectedTutorial}
                    onSubmit={handleSubmit}
                    onCancel={() => setShowForm(false)}
                  />
                </DialogContent>
              </Dialog>
            )}
            
            {/* Delete Confirmation Dialog */}
            <Dialog open={showDeleteConfirm} onOpenChange={setShowDeleteConfirm}>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Confirm Deletion</DialogTitle>
                  <DialogDescription>
                    Are you sure you want to delete the tutorial "{selectedTutorial?.title}"? 
                    This action cannot be undone.
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setShowDeleteConfirm(false)}>
                    Cancel
                  </Button>
                  <Button variant="destructive" onClick={handleDeleteConfirm}>
                    Delete
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
            
            {/* Delete All Confirmation Dialog */}
            <Dialog open={showDeleteAllConfirm} onOpenChange={setShowDeleteAllConfirm}>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Confirm Delete All</DialogTitle>
                  <DialogDescription>
                    Are you sure you want to delete ALL tutorials? This action cannot be undone 
                    and will remove {tutorials.length} tutorials from the database.
                  </DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <Button variant="outline" onClick={() => setShowDeleteAllConfirm(false)}>
                    Cancel
                  </Button>
                  <Button variant="destructive" onClick={handleDeleteAllConfirm}>
                    Delete All
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        )}
      </main>
      
      <Footer />
    </div>
  );
};

export default Index;

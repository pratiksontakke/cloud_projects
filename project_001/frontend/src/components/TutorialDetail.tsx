
import React from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Calendar } from "lucide-react";
import { Tutorial } from "@/services/tutorialService";

interface TutorialDetailProps {
  tutorial: Tutorial | null;
  onBack: () => void;
}

const TutorialDetail: React.FC<TutorialDetailProps> = ({ tutorial, onBack }) => {
  if (!tutorial) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Tutorial not found</CardTitle>
          <CardDescription>The requested tutorial could not be loaded.</CardDescription>
        </CardHeader>
        <CardContent>
          <Button onClick={onBack} className="flex items-center gap-2">
            <ArrowLeft size={16} />
            Back to list
          </Button>
        </CardContent>
      </Card>
    );
  }

  const formatDate = (dateString?: string) => {
    if (!dateString) return "N/A";
    const date = new Date(dateString);
    return date.toLocaleString();
  };

  return (
    <Card className="animate-fade-in">
      <CardHeader className="pb-4">
        <div className="flex justify-between items-start">
          <div>
            <Button 
              variant="ghost" 
              onClick={onBack} 
              className="mb-2 p-0 h-auto hover:bg-transparent"
            >
              <ArrowLeft size={18} className="mr-1" />
              Back to list
            </Button>
            <CardTitle className="text-2xl font-bold">{tutorial.title}</CardTitle>
            <CardDescription className="flex items-center mt-1 text-sm text-muted-foreground">
              <Calendar size={14} className="mr-1" />
              {tutorial.createdAt ? `Created: ${formatDate(tutorial.createdAt)}` : "No creation date"}
              {tutorial.updatedAt && tutorial.updatedAt !== tutorial.createdAt && 
                ` • Updated: ${formatDate(tutorial.updatedAt)}`}
            </CardDescription>
          </div>
          <Badge 
            className={tutorial.published ? "bg-green-500 hover:bg-green-600" : "bg-orange-500 hover:bg-orange-600"}
          >
            {tutorial.published ? "Published" : "Draft"}
          </Badge>
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-2">Description</h3>
            <div className="bg-gray-50 p-4 rounded-md">
              {tutorial.description || <span className="text-muted-foreground italic">No description provided</span>}
            </div>
          </div>
          
          <div>
            <h3 className="text-lg font-semibold mb-2">Tutorial Details</h3>
            <div className="space-y-2">
              <div className="flex items-center justify-between border-b pb-2">
                <span className="font-medium">ID</span>
                <span>{tutorial.id}</span>
              </div>
              <div className="flex items-center justify-between border-b pb-2">
                <span className="font-medium">Status</span>
                <span>{tutorial.published ? "Published" : "Draft"}</span>
              </div>
              <div className="flex items-center justify-between border-b pb-2">
                <span className="font-medium">Created At</span>
                <span>{formatDate(tutorial.createdAt)}</span>
              </div>
              <div className="flex items-center justify-between pb-2">
                <span className="font-medium">Last Updated</span>
                <span>{formatDate(tutorial.updatedAt)}</span>
              </div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

export default TutorialDetail;
